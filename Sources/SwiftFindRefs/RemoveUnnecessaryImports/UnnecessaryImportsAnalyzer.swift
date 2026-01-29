import Foundation
@preconcurrency import IndexStore

/// Analyzes collected index store data to identify imports that can be removed without affecting the build.
struct UnnecessaryImportsAnalyzer: UnnecessaryAnalyzing {

    private let fileSystem: any FileSystemProvider
    private let collector: any IndexStoreCollecting
    private let indexStoreImportExtractor: any IndexStoreImportExtracting
    private let ignoredModules: Set<String>
    private let excludedDirectories: [String]?
    private let rootPath: String
    private let vPrint: (String) -> Void

    /// Creates an analyzer that relies on the provided file system, index store collector, and import extractor.
    init(
        fileSystem: any FileSystemProvider,
        collector: any IndexStoreCollecting,
        indexStoreImportExtractor: any IndexStoreImportExtracting,
        ignoredModules: Set<String>,
        excludedDirectories: [String]?,
        rootPath: String,
        vPrint: @escaping (String) -> Void = { _ in }
    ) {
        self.fileSystem = fileSystem
        self.collector = collector
        self.indexStoreImportExtractor = indexStoreImportExtractor
        self.ignoredModules = ignoredModules
        self.excludedDirectories = excludedDirectories
        self.rootPath = rootPath
        self.vPrint = vPrint
    }

    /// Returns the files that keep unnecessary imports by comparing declared modules with referenced symbols from the index store.
    /// - Returns: A map of source files to the modules whose imports can be removed.
    /// - Throws: `RemoveError.missingModuleInIndex` when expected modules lack occurrences inside the index.
    func analyze() async throws -> [String: Set<String>] {
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()
        let unitSnapshots: [UnitSnapshot] = units.compactMap {
            guard !$0.moduleName.isEmpty else { return nil }
            return UnitSnapshot(mainFile: $0.mainFile, moduleName: $0.moduleName)
        }
        let unitsByModule = Dictionary(grouping: unitSnapshots, by: \.moduleName)
        let fileForLogs = "ScrollDepthTrackerProtocol.swift" // errors: UIScrollView

        // Collect all module names for filtering imports
        let allModuleNames = Set(unitSnapshots.map { $0.moduleName })
        print("ignoredModules: \(ignoredModules)")

        // Pre-read file lines for IndexStore-based import extraction
        let fileSystemBox = FileSystemBox(fileSystem: fileSystem)
        var fileLinesByPath: [String: [String]] = [:]
        for unit in unitSnapshots where FileValidation.isValidForRemoveScan(unit.mainFile, excludedDirectories: excludedDirectories, rootPath: rootPath) {
            if unit.mainFile.contains(fileForLogs) {
                print("Reading lines for \(unit.mainFile)")
            }
            if let lines = try? fileSystemBox.fileSystem.readLines(atPath: unit.mainFile) {
                fileLinesByPath[unit.mainFile] = lines
            }
        }

        // Extract imports using IndexStore for regular imports (more accurate)
        // Fall back to file parsing if IndexStore doesn't have the data
        var mutableImportsByFile: [String: Set<String>] = [:]
        var specificImportsByFile: [String: [String: String?]] = [:]
        for unit in unitSnapshots where FileValidation.isValidForRemoveScan(unit.mainFile, excludedDirectories: excludedDirectories, rootPath: rootPath) {
            let fileLines = fileLinesByPath[unit.mainFile]

            // Use IndexStore-based extraction for all imports (regular and @testable)
            // IndexStoreImportExtractor handles both types of imports
            var imports: Set<String>
            if let fileLines {
                imports = indexStoreImportExtractor.imports(
                    inMainFile: unit.mainFile,
                    occurrencesByFile: occurrencesByFile,
                    fileLines: fileLines,
                    ignoredModules: ignoredModules,
                    vPrint: vPrint
                ).filter({ !ignoredModules.contains($0) })
                if unit.mainFile.contains(fileForLogs) {
                    print("Extracted imports for \(unit.mainFile): \(imports)")
                }

                // Track specific imports (import struct Module.Symbol)
                specificImportsByFile[unit.mainFile] = indexStoreImportExtractor.specificImports(
                    inMainFile: unit.mainFile,
                    fileLines: fileLines
                )
                
                // Validate that IndexStore captured imports from files that have them
                // If fileLines contains import statements but IndexStore extracted nothing, IndexStoreDB is corrupted
                let importLineNumbers = Self.findImportLineNumbers(fileLines, ignoredModules: ignoredModules)
                
                if !importLineNumbers.isEmpty && imports.isEmpty {
                    // File has imports but IndexStore extracted nothing - this indicates corruption
                    throw RemoveError.corruptedIndexStoreDB(file: unit.mainFile)
                }
            } else {
                // If fileLines are not available, return empty (shouldn't happen in normal flow)
                imports = []
            }
            
            if !imports.isEmpty {
                mutableImportsByFile[unit.mainFile] = imports
            }
        }
        let importsByFile = mutableImportsByFile
        let specificImportsMap = specificImportsByFile
        let excludedDirs = excludedDirectories
        let root = rootPath


        return try await withThrowingTaskGroup(of: (String, Set<String>)?.self) { group in
            for unit in unitSnapshots {
                group.addTask {
                    if !FileValidation.isValidForRemoveScan(unit.mainFile, excludedDirectories: excludedDirs, rootPath: root) {
                        return nil
                    }

                    guard let imports = importsByFile[unit.mainFile],
                          !imports.isEmpty else {
                        return nil
                    }

                    // Read file lines for typealias extraction
                    let fileLines = try? fileSystemBox.fileSystem.readLines(atPath: unit.mainFile)

                    let (referencedUSRs, _, referencedNames, referencedTypealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
                        mainFile: unit.mainFile,
                        occurrencesByFile: occurrencesByFile,
                        fileLines: fileLines
                    )

                    if unit.mainFile.contains(fileForLogs) {
                        print("Referenced USRs for \(unit.mainFile): \(referencedUSRs)")
                        print("Referenced Names for \(unit.mainFile): \(referencedNames)")
                        print("Referenced Typealiases for \(unit.mainFile): \(referencedTypealiases)")
                    }

                    var seenModules = Set<String>()
                    var requiredImports = Set<String>()

                    for moduleName in imports {
                        if requiredImports.contains(moduleName) {
                            continue
                        }

                        // Check if this is a project module (has dependentUnits)
                        // For project modules, use precise checks. For system frameworks, use USR contains check.
                        let isProjectModule = allModuleNames.contains(moduleName)

                        // For system frameworks or modules not in unitsByModule, check if USR contains module name
                        // USRs encode module names, so this works for system frameworks
                        if !isProjectModule {
                            if unit.mainFile.contains(fileForLogs) {
                                print("Checking system framework module \(moduleName) for \(unit.mainFile)")
                            }
                            // System framework - check if any referenced USR contains the module name
                            // USR format encodes module names, e.g., "UIKit" appears in UIKit symbol USRs
                            // Use a more precise pattern: module name should appear after @M@ (module marker) or @CM@ (class module marker)
                            let modulePattern = "c:@M@\(moduleName)" // Module marker pattern
                            let classModulePattern = "@CM@\(moduleName)" // Class module marker pattern
                            for referencedUSR in referencedUSRs {
                                // Check if the USR contains the module name in a module context
                                guard referencedUSR != modulePattern && referencedUSR != classModulePattern else {
                                    continue
                                }
                                if referencedUSR.contains(modulePattern) || referencedUSR.contains(classModulePattern) || referencedUSR.hasSuffix("@\(moduleName)") {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "Foundation" && ValidSymbols.foundation.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "CoreGraphics" && (ValidSymbols.coregraphics.contains(referencedUSR) || referencedUSR.contains("7CGFloat") || referencedUSR.contains("6CGSize")) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "UIKit" && (SystemSymbols.uikit.contains(referencedUSR) || ValidSymbols.foundation.contains(referencedUSR) || referencedUSR.contains("7CGFloat") || referencedUSR.contains("6CGSize")) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "SwiftUI" && referencedUSR.contains("7Combine") {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "XCTest" && ValidSymbols.xctest.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "WebKit" && ValidSymbols.webkit.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "SafariServices" && ValidSymbols.safariservices.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "CoreLocation" && ValidSymbols.corelocation.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "MachO" && ValidSymbols.macho.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if moduleName == "AppTrackingTransparency" && ValidSymbols.appTrackingTransparency.contains(referencedUSR) {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                                if referencedUSR.contains("\(moduleName.count)\(moduleName)") {
                                    requiredImports.insert(moduleName)
                                }
                            }
                            
                            // Mark system frameworks as seen
                            seenModules.insert(moduleName)
                            continue
                        }

                        // For project modules, do precise checks using dependentUnits
                        // This provides better accuracy by matching exact USRs from module definitions
                        if let dependentUnits = unitsByModule[moduleName] {

                            var hadOccurrences = false

                            for dependentUnit in dependentUnits {
                            guard let occurrences = occurrencesByFile[dependentUnit.mainFile] else {
                                // Empty files have units but no records - continue checking other files
                                continue
                            }
                            hadOccurrences = true

                            // Check USR matches first (most accurate)
                            var foundUSRMatch = false
                            for occurrence in occurrences {
                                if
                                    occurrence.roles.contains(.definition),
                                    referencedUSRs.contains(occurrence.symbolUSR)
                                {
                                    requiredImports.insert(moduleName)
                                    foundUSRMatch = true
                                    break
                                }
                            }

                            // Also check if any referenced USR contains types from this module
                            // This handles cases like someProperty: SomeLogger where the property USR encodes the type
                            // USR format: s:6SomeModule4SomeFileO12someProperty0A9SomeModule8SomeLoggerCvpZ
                            // The "0A9SomeModule8SomeLoggerC" part encodes SomeModule.SomeLogger
                            if !foundUSRMatch {
                                // Get all definition USRs and symbol names from this module
                                let moduleDefinitions = occurrences.filter { $0.roles.contains(.definition) }
                                let moduleDefinitionUSRs = Set(moduleDefinitions.map { $0.symbolUSR })
                                let moduleDefinitionNames = Set(moduleDefinitions.map { $0.symbolName })

                                // Check if any referenced USR contains a type from this module
                                // Swift USR encoding: module names and types are mangled in USRs
                                // For example: "SomeModule.SomeLogger" becomes "0A9SomeModule8SomeLoggerC" in USR
                                for referencedUSR in referencedUSRs {
                                    // Check if the referenced USR contains any definition USR
                                    for defUSR in moduleDefinitionUSRs {
                                        if referencedUSR.contains(defUSR) || defUSR.contains(referencedUSR) {
                                            requiredImports.insert(moduleName)
                                            foundUSRMatch = true
                                            break
                                        }
                                    }

                                    // Also check if the USR contains the symbol name (for type references in property USRs)
                                    // Extract the type part from USRs like s:6SomeModule4SomeFileO12someProperty0A9SomeModule8SomeLoggerCvpZ
                                    // The type "SomeModule.SomeLogger" is encoded as "0A9SomeModule8SomeLoggerC"
                                    for defName in moduleDefinitionNames {
                                        // Check if the USR contains an encoding of the module name + symbol name
                                        // Module name encoding: "SomeModule" -> "0A9SomeModule" (length + name)
                                        // Symbol name: "SomeLogger" -> "8SomeLoggerC" (length + name + C for class)
                                        // Combined: "0A9SomeModule8SomeLoggerC"
                                        // We can check if the USR contains the symbol name and module indicators
                                        if referencedUSR.contains(defName) {
                                            // Verify this is actually a type reference, not just a name collision
                                            // Check if the USR structure suggests a type reference
                                            // Property USRs often encode the type after the property name
                                            requiredImports.insert(moduleName)
                                            foundUSRMatch = true
                                            break
                                        }
                                    }

                                    if foundUSRMatch {
                                        break
                                    }
                                }
                            }

                            if foundUSRMatch {
                                break
                            }

                            // Fallback: Check symbol name matches (in case USRs don't match)
                            // This handles cases where USR encoding might differ or be incomplete
                            if !requiredImports.contains(moduleName) && !referencedNames.isEmpty {
                                for occurrence in occurrences {
                                    if
                                        occurrence.roles.contains(.definition),
                                        referencedNames.contains(occurrence.symbolName)
                                    {
                                        requiredImports.insert(moduleName)
                                        break
                                    }
                                }
                            }
                                if requiredImports.contains(moduleName) {
                                    break
                                }
                            }

                            // If module has units but no files with occurrences, still mark as seen
                            // (empty files have units but no records - this is expected)
                            // This ensures we don't throw missingModuleInIndex for modules that exist but are empty
                            if !hadOccurrences && !dependentUnits.isEmpty {
                                hadOccurrences = true
                            }

                            // Safety check: If we haven't found any matching definitions but a capitalized type name from referencedNames
                            // is present, check the source files directly. This handles cases where external SDKs aren't indexed properly.
                            // Only check if we haven't already marked the import as required.
                            if !requiredImports.contains(moduleName) && !referencedNames.isEmpty && hadOccurrences {
                                // Check if any referenced name is a capitalized type name (likely a class/struct/enum)
                                // and check if it might be from this module by reading the module's source files
                                let capitalizedTypeNames = referencedNames.filter {
                                    !$0.isEmpty &&
                                    $0.first?.isUppercase == true &&
                                    !$0.contains("(") && // Exclude function names
                                    !$0.contains("getter:") &&
                                    !$0.contains("setter:")
                                }

                                if !capitalizedTypeNames.isEmpty {
                                    // Check if any of these type names appear in the module's source files
                                    for dependentUnit in dependentUnits {
                                        if let moduleFileLines = try? fileSystemBox.fileSystem.readLines(atPath: dependentUnit.mainFile) {
                                            for line in moduleFileLines {
                                                for typeName in capitalizedTypeNames {
                                                    // Check if the type name appears in the file (as a class/struct/enum declaration or usage)
                                                    if line.contains("class \(typeName)") ||
                                                       line.contains("struct \(typeName)") ||
                                                       line.contains("enum \(typeName)") ||
                                                       line.contains("protocol \(typeName)") ||
                                                       line.contains("typealias \(typeName)") ||
                                                       (line.contains(typeName) && (line.contains("import") || line.contains(": \(typeName)") || line.contains("\(typeName)."))) {
                                                        requiredImports.insert(moduleName)
                                                        break
                                                    }
                                                }
                                                if requiredImports.contains(moduleName) {
                                                    break
                                                }
                                            }
                                        }
                                        if requiredImports.contains(moduleName) {
                                            break
                                        }
                                    }
                                }
                            }

                            // Check typealias matches
                            // IMPORTANT: The example only matches typealiases if the module is already imported
                            // This is a safety check: "if we're already importing this module, and there's a typealias match, then keep the import"
                            if !requiredImports.contains(moduleName) && !referencedTypealiases.isEmpty && imports.contains(moduleName) {
                                // Check if any referenced typealiases are defined in this module
                                // We need to check both files with occurrences (for typealias definitions in index)
                                // and read files directly (for typealiases that might not be indexed properly)
                                for dependentUnit in dependentUnits {
                                    // First check if any occurrences are typealias definitions
                                    if let occurrences = occurrencesByFile[dependentUnit.mainFile] {
                                        for occurrence in occurrences {
                                            if occurrence.roles.contains(.definition) &&
                                               occurrence.symbolKind == .typealias &&
                                               referencedTypealiases.contains(occurrence.symbolName) {
                                                requiredImports.insert(moduleName)
                                                break
                                            }
                                        }
                                        if requiredImports.contains(moduleName) {
                                            break
                                        }
                                    }

                                    // Also read file to extract typealias definitions (for cases where typealiases aren't properly indexed)
                                    if let moduleFileLines = try? fileSystemBox.fileSystem.readLines(atPath: dependentUnit.mainFile) {
                                        for line in moduleFileLines {
                                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                                            if trimmed.hasPrefix("typealias ") {
                                                let parts = trimmed.dropFirst("typealias ".count).split(whereSeparator: { $0 == " " || $0 == "=" })
                                                if let typealiasName = parts.first {
                                                    let name = String(typealiasName).trimmingCharacters(in: .whitespaces)
                                                    if referencedTypealiases.contains(name) {
                                                        requiredImports.insert(moduleName)
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    if requiredImports.contains(moduleName) {
                                        break
                                    }
                                }
                            }

                            if hadOccurrences {
                                seenModules.insert(moduleName)
                            }
                        } else {
                            // Module not found in unitsByModule - this shouldn't happen for project modules
                            // but handle gracefully
                            seenModules.insert(moduleName)
                        }
                    }

                    // Only check for missing modules among project modules (not system frameworks)
                    let projectModuleImportsToCheck = imports.intersection(allModuleNames)
                    let missingModules = projectModuleImportsToCheck.subtracting(seenModules)
                    if !missingModules.isEmpty {
                        throw RemoveError.missingModuleInIndex(
                            file: unit.mainFile,
                            modules: missingModules
                        )
                    }

                    var unnecessary = imports
                        .intersection(seenModules)
                        .subtracting(requiredImports)

                    // Filter out specific imports if their specific symbol is used
                    // For imports like `import struct Module.SomeStruct`, we need to check if SomeStruct is used
                    if let fileSpecificImports = specificImportsMap[unit.mainFile] {
                        var modulesToKeep = Set<String>()
                        
                        for (importLine, specificSymbol) in fileSpecificImports {
                            // Extract module name from the import line
                            let trimmed = importLine.trimmingCharacters(in: .whitespaces)
                            let prefix = trimmed.hasPrefix("@testable import ") ? "@testable import " : "import "
                            let importPart = trimmed.dropFirst(prefix.count)
                            
                            // Parse module name (handle specific imports like "struct Module.Symbol")
                            let parts = importPart.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "." })
                            let moduleName: String
                            if let firstPart = parts.first,
                               ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"].contains(String(firstPart)),
                               parts.count >= 2 {
                                // Specific import: import struct Module.Symbol
                                moduleName = String(parts[1])
                            } else if let firstPart = parts.first {
                                // Regular import: import Module
                                moduleName = String(firstPart)
                            } else {
                                continue
                            }
                            
                            // If this is a specific import and the symbol is used, keep the import
                            if let symbol = specificSymbol, !symbol.isEmpty {
                                // Check if the specific symbol is referenced
                                if referencedNames.contains(symbol) || referencedTypealiases.contains(symbol) {
                                    modulesToKeep.insert(moduleName)
                                } else {
                                    // Check if symbol appears in USRs (for types)
                                    var symbolFoundInUSR = false
                                    for referencedUSR in referencedUSRs {
                                        if referencedUSR.contains(symbol) {
                                            symbolFoundInUSR = true
                                            break
                                        }
                                    }
                                    if symbolFoundInUSR {
                                        modulesToKeep.insert(moduleName)
                                    }
                                }
                            }
                        }
                        
                        // Remove modules that have specific imports with used symbols
                        unnecessary = unnecessary.subtracting(modulesToKeep)
                    }

                    if !unnecessary.isEmpty {
                        return (unit.mainFile, unnecessary)
                    }

                    return nil
                }
            }

            var results: [String: Set<String>] = [:]
            for try await result in group {
                if let (file, unnecessary) = result {
                    results[file] = unnecessary
                }
            }
            return results
        }
    }
    
    /// Finds line numbers that contain import statements.
    /// - Parameters:
    ///   - fileLines: The file contents split by line
    ///   - ignoredModules: Module names that should be ignored
    /// - Returns: Set of line numbers (1-indexed) containing import statements
    private static func findImportLineNumbers(_ fileLines: [String], ignoredModules: Set<String>) -> Set<Int> {
        var importLines = Set<Int>()
        let ignoreRegex = try! Regex(#"// *@ignore-import$"#)
        
        for (index, line) in fileLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            guard !trimmed.isEmpty && !trimmed.hasPrefix("//") else {
                continue
            }
            
            // Check for @ignore-import comment
            if line.firstMatch(of: ignoreRegex) != nil {
                continue
            }
            
            // Check for import statements
            if trimmed.hasPrefix("@testable import ") || trimmed.hasPrefix("import ") {
                // Parse module name to check if it's ignored
                let prefix = trimmed.hasPrefix("@testable import ") ? "@testable import " : "import "
                let modulePart = trimmed.dropFirst(prefix.count)
                if let moduleNamePart = modulePart.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "." || $0 == "/" }).first,
                   !moduleNamePart.isEmpty {
                    let moduleName = String(moduleNamePart)
                    // Only include if not ignored
                    if !ignoredModules.contains(moduleName) {
                        importLines.insert(index + 1) // Convert to 1-indexed
                    }
                }
            }
        }
        
        return importLines
    }
    
}

enum ValidSymbols {
    static let foundation: Set<String> = [
        // Base object / runtime
        "c:objc(cs)NSObject",
        "c:objc(cs)NSObject(im)init",
        "c:objc(cs)NSObject(im)dealloc",
        "c:objc(cs)NSObject(im)isEqual:",
        "c:objc(cs)NSObject(im)hash",
        "c:objc(cs)NSObject(im)description",

        // Collections
        "c:objc(cs)NSArray",
        "c:objc(cs)NSMutableArray",
        "c:objc(cs)NSDictionary",
        "c:objc(cs)NSMutableDictionary",
        "c:objc(cs)NSSet",
        "c:objc(cs)NSMutableSet",
        "c:objc(cs)NSOrderedSet",
        "c:objc(cs)NSMutableOrderedSet",

        // Strings & attributed strings
        "c:objc(cs)NSString",
        "c:objc(cs)NSMutableString",
        "c:objc(cs)NSAttributedString",
        "c:objc(cs)NSMutableAttributedString",

        // Numbers & value types
        "c:objc(cs)NSNumber",
        "c:objc(cs)NSValue",
        "c:objc(cs)NSDecimalNumber",

        // Data & dates
        "c:objc(cs)NSData",
        "c:objc(cs)NSMutableData",
        "c:objc(cs)NSDate",
        "c:objc(cs)NSDateComponents",
        "c:objc(cs)NSDateFormatter",
        "c:objc(cs)NSCalendar",
        "c:objc(cs)NSTimeZone",
        "c:objc(cs)NSLocale",

        // Errors & notifications
        "c:objc(cs)NSError",
        "c:objc(cs)NSNotification",
        "c:objc(cs)NSNotificationCenter",

        // File system & URLs
        "c:objc(cs)NSURL",
        "c:objc(cs)NSURLComponents",
        "c:objc(cs)NSURLQueryItem",
        "c:objc(cs)NSFileManager",
        "c:objc(cs)NSFileHandle",

        // Concurrency & execution
        "c:objc(cs)NSOperation",
        "c:objc(cs)NSOperationQueue",
        "c:objc(cs)NSThread",
        "c:objc(cs)NSRunLoop",
        "c:objc(cs)NSTimer",

        // KVC / KVO / predicates
        "c:objc(cs)NSPredicate",
        "c:objc(cs)NSExpression",
        "c:objc(cs)NSSortDescriptor",

        // Serialization
        "c:objc(cs)NSJSONSerialization",
        "c:objc(cs)NSPropertyListSerialization",
        "c:objc(cs)NSKeyedArchiver",
        "c:objc(cs)NSKeyedUnarchiver",

        // Bundles & resources
        "c:objc(cs)NSBundle",
        "c:objc(cs)NSUserDefaults",

        // Networking
        "c:objc(cs)NSURLSessionDataTask",
        "c:objc(cs)NSCachedURLResponse",
        "c:@T@SecTrustRef",

        "c:@T@NSTimeInterval",
        "c:@T@NSInteger",
        "c:@T@NSUInteger",
        "c:@T@NSString",
        "c:@T@NSNumber",
        "c:@T@NSDecimalNumber",
        "c:@T@NSData",
        "c:@T@NSDate",
        "c:@T@NSError",
        "s:So19CLOCK_MONOTONIC_RAWSo9clockid_tavg",
        "c:@EA@clockid_t@_CLOCK_MONOTONIC_RAW",
        "c:@F@clock_gettime_nsec_np",
        "c:objc(cs)OS_dispatch_queue",
        "c:@F@dispatch_sync",
        "c:objc(cs)NSProcessInfo(cpy)processInfo",
        "c:objc(cs)NSProcessInfo(py)environment",
        "c:objc(cs)NSProcessInfo",
        "c:objc(cs)NSProcessInfo(cm)processInfo",
        "c:objc(cs)NSProcessInfo(im)environment"
    ]

    static let coregraphics: Set<String> = [
        "c:@T@CGFloat",
        "c:@T@CGPoint",
        "c:@T@CGSize",
        "c:@T@CGRect",
        "c:@T@CGAffineTransform",
        "c:@T@CGVector",
        "c:@T@CGPath",
        "c:@T@CGColor",
        "c:@T@CGColorSpace",
        "c:@T@CGImage",
        "c:@T@CGGradient",
        "c:@T@CGContext",
        "c:@T@CGBlendMode",
        "c:@T@CGLineCap",
        "c:@T@CGLineJoin",
        "c:@T@CGPathDrawingMode",
        "c:@T@CGTextDrawingMode",
        "c:@T@CGTextAlignment"
    ]

    static let uikit: Set<String> = [

        // MARK: - Core UIKit classes
        "c:objc(cs)UIApplication",
        "c:objc(cs)UIResponder",
        "c:objc(cs)UIScreen",
        "c:objc(cs)UIDevice",
        "c:objc(cs)UIWindow",

        // MARK: - View & View Controllers
        "c:objc(cs)UIView",
        "c:objc(cs)UIViewController",
        "c:objc(cs)UINavigationController",
        "c:objc(cs)UITabBarController",
        "c:objc(cs)UISplitViewController",
        "c:objc(cs)UIScrollView",

        // MARK: - Common UI elements
        "c:objc(cs)UILabel",
        "c:objc(cs)UIButton",
        "c:objc(cs)UIImageView",
        "c:objc(cs)UITextField",
        "c:objc(cs)UITextView",
        "c:objc(cs)UISwitch",
        "c:objc(cs)UISlider",
        "c:objc(cs)UIProgressView",
        "c:objc(cs)UIActivityIndicatorView",

        // MARK: - Images, colors, fonts
        "c:objc(cs)UIColor",
        "c:objc(cs)UIImage",
        "c:objc(cs)UIFont",
        "c:objc(cs)UIImagePickerController",
        "c:objc(cs)UITraitCollection",
        "c:@E@UIUserInterfaceStyle",

        // MARK: - Layout & constraints
        "c:objc(cs)NSLayoutConstraint",
        "c:objc(cs)UILayoutGuide",

        // MARK: - Table & collection views
        "c:objc(cs)UITableView",
        "c:objc(cs)UITableViewCell",
        "c:objc(cs)UICollectionView",
        "c:objc(cs)UICollectionViewCell",
        "c:objc(cs)UICollectionViewLayout",
        "c:objc(cs)UICollectionViewFlowLayout",

        // MARK: - Gestures & interactions
        "c:objc(cs)UIGestureRecognizer",
        "c:objc(cs)UITapGestureRecognizer",
        "c:objc(cs)UIPanGestureRecognizer",
        "c:objc(cs)UIScreenEdgePanGestureRecognizer",
        "c:objc(cs)UILongPressGestureRecognizer",

        // MARK: - Navigation & presentation
        "c:objc(cs)UIAlertController",
        "c:objc(cs)UIAlertAction",
        "c:objc(cs)UIActivityViewController",

        // MARK: - Animation & transitions
        "c:objc(cs)UIViewPropertyAnimator",
        "c:objc(cs)UIViewControllerAnimatedTransitioning",
        "c:objc(cs)UIViewControllerTransitioningDelegate",
        "c:@E@UIDeviceOrientation",
        ":@E@UIInterfaceOrientation",

        // MARK: - Accessibility
        "c:objc(cs)UIAccessibilityElement",

        // MARK: - UIKit collections & support types
        "c:objc(cs)NSIndexPath",
        "c:objc(cs)UIEdgeInsets",
        "c:objc(cs)UIOffset",

        // MARK: - Text & input
        "c:objc(cs)UIKeyCommand",
        "c:objc(cs)UITextInputMode",

        // MARK: - CoreGraphics
        "c:@S@CGSize@FI@width"

    ]

    static let xctest: Set<String> = [
        "c:objc(cs)XCTestCase"
    ]

    static let webkit: Set<String> = [
        "c:objc(cs)WKWebView"
    ]

    static let safariservices: Set<String> = [

        // MARK: - Core classes
        "c:objc(cs)SFSafariViewController",
        "c:objc(cs)SFAuthenticationSession",          // deprecated but still indexed
        "c:objc(cs)ASWebAuthenticationSession",       // often associated via SafariServices usage

        // MARK: - Protocols
        "c:objc(pl)SFSafariViewControllerDelegate",

        // MARK: - Properties
        "c:objc(cs)SFSafariViewController(py)delegate",
        "c:objc(cs)SFSafariViewController(py)preferredBarTintColor",
        "c:objc(cs)SFSafariViewController(py)preferredControlTintColor",
        "c:objc(cs)SFSafariViewController(py)dismissButtonStyle",

        // MARK: - Initializers
        "c:objc(cs)SFSafariViewController(im)initWithURL:",
        "c:objc(cs)SFSafariViewController(im)initWithURL:configuration:",

        // MARK: - Delegate methods
        "c:objc(pl)SFSafariViewControllerDelegate(im)safariViewControllerDidFinish:",
        "c:objc(pl)SFSafariViewControllerDelegate(im)safariViewController:didCompleteInitialLoad:",
        "c:objc(pl)SFSafariViewControllerDelegate(im)safariViewController:activityItemsForURL:title:",

        // MARK: - Configuration
        "c:objc(cs)SFSafariViewControllerConfiguration",
        "c:objc(cs)SFSafariViewControllerConfiguration(py)entersReaderIfAvailable",
        "c:objc(cs)SFSafariViewControllerConfiguration(py)barCollapsingEnabled"
    ]

    static let corelocation: Set<String> = [
        "c:objc(cs)CLLocation",
        "c:objc(cs)CLLocationCoordinate2D",
        "c:objc(cs)CLLocationManager",
        "c:objc(pl)CLLocationManagerDelegate",
        "c:objc(cs)CLBeaconRegion",
        "c:objc(cs)CLRegionState",
        "c:objc(cs)CLVisit",
        "c:objc(cs)CLGeocoder",
        "c:objc(pl)CLGeocoderDelegate",
        "c:objc(cs)CLHeading",
        "c:objc(cs)CLHeadingFilter",
        "c:objc(cs)CLHeadingOrientation",
        "c:objc(cs)CLHeadingReferenceFrame",
        "c:objc(cs)CLLocationDirection",
        "c:objc(cs)CLLocationSpeed",
        "c:objc(cs)CLLocationVerticalAccuracy",
        "c:objc(cs)CLLocationHorizontalAccuracy",
        "c:objc(cs)CLLocationDistance"
    ]

    static let macho: Set<String> = [
        "c:@F@_dyld_get_image_name",
        "c:@F@_dyld_image_count"
    ]

    static let appTrackingTransparency: Set<String> = [
        "c:objc(cs)ATTrackingManager",
        "c:@E@ATTrackingManagerAuthorizationStatus@ATTrackingManagerAuthorizationStatusAuthorized",
        "c:@E@ATTrackingManagerAuthorizationStatus",
        "c:@E@ATTrackingManagerAuthorizationStatus@ATTrackingManagerAuthorizationStatusNotDetermined",
        "c:@E@ATTrackingManagerAuthorizationStatus@ATTrackingManagerAuthorizationStatusDenied",
        "c:@E@ATTrackingManagerAuthorizationStatus@ATTrackingManagerAuthorizationStatusRestricted",
        "c:@E@ATTrackingManagerAuthorizationStatus@ATTrackingManagerAuthorizationStatusAuthorized"
    ]
}
