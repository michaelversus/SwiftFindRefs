import Foundation
@preconcurrency import IndexStore

/// Analyzes testable import statements to find those that are not required for any referenced symbols.
struct UnnecessaryTestableAnalyzer: UnnecessaryAnalyzing {
    private let fileSystem: any FileSystemProvider
    private let extractor: any ImportExtracting
    private let collector: any IndexStoreCollecting

    /// Initializes an analyzer with the collaborators needed to walk imports and index store data.
    init(
        fileSystem: FileSystemProvider,
        extractor: ImportExtracting,
        collector: any IndexStoreCollecting
    ) {
        self.fileSystem = fileSystem
        self.extractor = extractor
        self.collector = collector
    }

    /// Returns a mapping from file paths to the set of `@testable` imports that are not required by any referenced symbol.
    /// - Returns: A dictionary keyed by source file path containing unnecessary `@testable` module names.
    /// - Throws: Propagates errors from the collector, extractor, or file system, and `RemoveError` when the index store lacks data for a declared testable module.
    func analyze() async throws -> [String: Set<String>] {
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()
        let unitSnapshots = units.map { UnitSnapshot(mainFile: $0.mainFile, moduleName: $0.moduleName) }
        let unitsByModule = Dictionary(grouping: unitSnapshots, by: \.moduleName)
        let fileSystemBox = FileSystemBox(fileSystem: fileSystem)
        let fileLinesCache = FileLinesCache(
            readLines: { path in
                try fileSystemBox.fileSystem.readLines(atPath: path)
            }
        )
        var mutableTestableImportsByFile: [String: Set<String>] = [:]
        for unit in unitSnapshots where !FileValidation.isGeneratedFile(unit.mainFile) && !FileValidation.isThirdPartyFile(unit.mainFile) {
            let testableImports = try await extractor.imports(inFile: unit.mainFile)
            if !testableImports.isEmpty {
                mutableTestableImportsByFile[unit.mainFile] = testableImports
            }
        }
        let testableImportsByFile = mutableTestableImportsByFile

        return try await withThrowingTaskGroup(of: (String, Set<String>)?.self) { group in
            for unit in unitSnapshots {
                group.addTask {
                    if FileValidation.isGeneratedFile(unit.mainFile) || FileValidation.isThirdPartyFile(unit.mainFile) {
                        return nil
                    }

                    guard let testableImports = testableImportsByFile[unit.mainFile],
                          !testableImports.isEmpty else {
                        return nil
                    }

                    let (referencedUSRs, overrideUSRs) = UnnecessaryTestableSRResolver.getReferenceUSRs(
                        mainFile: unit.mainFile,
                        occurrencesByFile: occurrencesByFile
                    )
                    var seenModules = Set<String>()
                    var requiredTestableImports = Set<String>()

                    for moduleName in testableImports {
                        if requiredTestableImports.contains(moduleName) {
                            continue
                        }
                        guard let dependentUnits = unitsByModule[moduleName] else {
                            continue
                        }

                        var hadOccurrences = false
                        for dependentUnit in dependentUnits {
                            guard let occurrences = occurrencesByFile[dependentUnit.mainFile] else {
                                continue
                            }
                            hadOccurrences = true

                            for occurrence in occurrences {
                                if
                                    occurrence.roles.contains(.definition),
                                    referencedUSRs.contains(occurrence.symbolUSR),
                                    !Self.isChildOfProtocol(occurrence: occurrence),
                                    !Self.isGetterOrSetterFunction(occurrence: occurrence),
                                    !(await Self.isPublic(
                                        file: dependentUnit.mainFile,
                                        occurrence: occurrence,
                                        isOverride: overrideUSRs.contains(occurrence.symbolUSR),
                                        fileLinesCache: fileLinesCache
                                    ))
                                {
                                    requiredTestableImports.insert(moduleName)
                                    break
                                }
                            }
                            if requiredTestableImports.contains(moduleName) {
                                break
                            }
                        }
                        if hadOccurrences {
                            seenModules.insert(moduleName)
                        }
                    }

                    let missingTestableModules = testableImports.subtracting(seenModules)
                    if !missingTestableModules.isEmpty {
                        throw RemoveError.missingModuleInIndex(
                            file: unit.mainFile,
                            modules: missingTestableModules
                        )
                    }

                    let unnecessary = testableImports
                        .intersection(seenModules)
                        .subtracting(requiredTestableImports)
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

    /// Determines whether a recorded occurrence should be treated as public for filtering purposes.
    /// - Parameters:
    ///  - file: The source file path containing the occurrence.
    ///  - occurrence: The occurrence snapshot to evaluate.
    ///  - isOverride: Indicates whether the occurrence represents an override of a superclass method.
    ///  - fileLinesCache: A cache for reading lines from source files.
    ///  - Returns: `true` when the occurrence is considered public; otherwise `false`.
    private static func isPublic(
        file: String,
        occurrence: OccurrenceSnapshot,
        isOverride: Bool,
        fileLinesCache: FileLinesCache
    ) async -> Bool {
        if occurrence.roles.contains(.implicit) && !occurrence.roles.contains(.accessorOf) {
            return false
        }

        if occurrence.symbolKind == .enumConstant {
            return true
        }

        let lines = await fileLinesCache.lines(for: file)
        let lineIndex = occurrence.locationLine - 1
        guard lineIndex >= 0, lineIndex < lines.count else {
            return false
        }
        let text = lines[lineIndex]
        let isPublic = (text.contains("public ") && !isOverride) || text.contains("open ")
        return isPublic && !text.contains(" internal(")
    }

    /// Returns `true` when an occurrence represents a member of a protocol so its visibility can be ignored.
    /// - Parameter occurrence: The occurrence snapshot to evaluate.
    /// - Returns: `true` when the occurrence is a protocol child; otherwise `false`.
    private static func isChildOfProtocol(occurrence: OccurrenceSnapshot) -> Bool {
        let protocolChildrenTypes: [SymbolKind] = [
            .instanceMethod, .classMethod, .staticMethod,
            .instanceProperty, .classProperty, .staticProperty,
        ]
        guard protocolChildrenTypes.contains(occurrence.symbolKind) else {
            return false
        }

        for related in occurrence.relatedSymbols {
            if related.roles.contains(.childOf) && related.kind == .protocol {
                return true
            }
        }
        return false
    }

    /// Returns `true` for occurrences that are getter/setter accessors rather than standalone functions.
    /// - Parameter occurrence: The occurrence snapshot to evaluate.
    /// - Returns: `true` when the occurrence is a getter or setter; otherwise `false`.
    private static func isGetterOrSetterFunction(occurrence: OccurrenceSnapshot) -> Bool {
        let functionTypes: [SymbolKind] = [.classMethod, .instanceMethod, .staticMethod]
        guard functionTypes.contains(occurrence.symbolKind) else {
            return false
        }
        return occurrence.roles.contains(.accessorOf)
    }
}
