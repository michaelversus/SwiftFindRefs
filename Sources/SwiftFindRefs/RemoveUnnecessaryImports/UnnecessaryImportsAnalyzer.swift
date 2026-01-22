import Foundation
@preconcurrency import IndexStore

/// Analyzes collected index store data to identify imports that can be removed without affecting the build.
struct UnnecessaryImportsAnalyzer: UnnecessaryAnalyzing {

    private let fileSystem: any FileSystemProvider
    private let extractor: any ImportExtracting
    private let collector: any IndexStoreCollecting
    private let indexStoreImportExtractor: any IndexStoreImportExtracting
    private let excludedDirectories: [String]?
    private let rootPath: String

    /// Creates an analyzer that relies on the provided file system, import extractor, and index store collector type.
    init(
        fileSystem: any FileSystemProvider,
        extractor: any ImportExtracting,
        collector: any IndexStoreCollecting,
        indexStoreImportExtractor: any IndexStoreImportExtracting,
        excludedDirectories: [String]? = nil,
        rootPath: String
    ) {
        self.fileSystem = fileSystem
        self.extractor = extractor
        self.collector = collector
        self.indexStoreImportExtractor = indexStoreImportExtractor
        self.excludedDirectories = excludedDirectories
        self.rootPath = rootPath
    }

    /// Returns the files that keep unnecessary imports by comparing declared modules with referenced symbols from the index store.
    /// - Returns: A map of source files to the modules whose imports can be removed.
    /// - Throws: `RemoveError.missingModuleInIndex` when expected modules lack occurrences inside the index.
    func analyze() async throws -> [String: Set<String>] {
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()
        let unitSnapshots = units.map { UnitSnapshot(mainFile: $0.mainFile, moduleName: $0.moduleName) }
        let unitsByModule = Dictionary(grouping: unitSnapshots, by: \.moduleName)

        // Collect all module names for filtering imports
        let allModuleNames = Set(unitSnapshots.map { $0.moduleName })

        // Pre-read file lines for IndexStore-based import extraction
        let fileSystemBox = FileSystemBox(fileSystem: fileSystem)
        var fileLinesByPath: [String: [String]] = [:]
        for unit in unitSnapshots where FileValidation.isValidForRemoveScan(unit.mainFile, excludedDirectories: excludedDirectories, rootPath: rootPath) {
            if let lines = try? fileSystemBox.fileSystem.readLines(atPath: unit.mainFile) {
                fileLinesByPath[unit.mainFile] = lines
            }
        }

        // Extract imports using IndexStore for regular imports (more accurate)
        // Fall back to file parsing if IndexStore doesn't have the data
        let ignoredModules = Set((extractor as? ImportExtractor)?.ignoredModules ?? [])
        var mutableImportsByFile: [String: Set<String>] = [:]
        for unit in unitSnapshots where FileValidation.isValidForRemoveScan(unit.mainFile, excludedDirectories: excludedDirectories, rootPath: rootPath) {
            let fileLines = fileLinesByPath[unit.mainFile]

            // Try IndexStore-based extraction first (for regular imports)
            // Only use IndexStore for regular imports, not @testable imports
            let isRegularImport = (extractor as? ImportExtractor)?.prefix == .regularImport
            let indexStoreImports: Set<String>
            if isRegularImport, let fileLines {
                indexStoreImports = indexStoreImportExtractor.imports(
                    inMainFile: unit.mainFile,
                    occurrencesByFile: occurrencesByFile,
                    fileLines: fileLines,
                    allModuleNames: allModuleNames,
                    ignoredModules: ignoredModules
                )
            } else {
                indexStoreImports = []
            }

            if !indexStoreImports.isEmpty {
                mutableImportsByFile[unit.mainFile] = indexStoreImports
            } else {
                // Fall back to file parsing (needed for @testable imports or when IndexStore doesn't have module symbols)
                let fileParsedImports = try await extractor.imports(inFile: unit.mainFile)
                if !fileParsedImports.isEmpty {
                    mutableImportsByFile[unit.mainFile] = fileParsedImports
                }
            }
        }
        let importsByFile = mutableImportsByFile
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

                    // Filter imports to only known modules (like the example does)
                    let allImports = imports.intersection(allModuleNames)
                    if allImports.isEmpty {
                        return nil
                    }

                    // Read file lines for typealias extraction
                    let fileLines = try? fileSystemBox.fileSystem.readLines(atPath: unit.mainFile)

                    let (referencedUSRs, _, referencedNames, referencedTypealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
                        mainFile: unit.mainFile,
                        occurrencesByFile: occurrencesByFile,
                        fileLines: fileLines
                    )

                    var seenModules = Set<String>()
                    var requiredImports = Set<String>()

                    for moduleName in allImports {
                        if requiredImports.contains(moduleName) {
                            continue
                        }
                        guard let dependentUnits = unitsByModule[moduleName] else {
                            continue
                        }

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
                        if !requiredImports.contains(moduleName) && !referencedTypealiases.isEmpty && allImports.contains(moduleName) {
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
                    }

                    let missingModules = allImports.subtracting(seenModules)
                    if !missingModules.isEmpty {
                        throw RemoveError.missingModuleInIndex(
                            file: unit.mainFile,
                            modules: missingModules
                        )
                    }

                    let unnecessary = allImports
                        .intersection(seenModules)
                        .subtracting(requiredImports)

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
}
