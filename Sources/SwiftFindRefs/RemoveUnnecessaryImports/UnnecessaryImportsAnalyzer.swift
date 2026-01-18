import Foundation
@preconcurrency import IndexStore

struct UnnecessaryImportsAnalyzer: UnnecessaryAnalyzing {
    private let fileSystem: FileSystemProvider
    private let extractor: ImportExtracting
    private let collector: any IndexStoreCollecting.Type

    init(
        fileSystem: FileSystemProvider,
        extractor: ImportExtracting,
        collector: any IndexStoreCollecting.Type
    ) {
        self.fileSystem = fileSystem
        self.extractor = extractor
        self.collector = collector
    }

    func analyze(store: some IndexStoreProviding, indexStorePath: String) async throws -> [String: Set<String>] {
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords(from: store, indexStorePath: indexStorePath)
        let unitSnapshots = units.map { UnitSnapshot(mainFile: $0.mainFile, moduleName: $0.moduleName) }
        let unitsByModule = Dictionary(grouping: unitSnapshots, by: \.moduleName)
        var mutableImportsByFile: [String: Set<String>] = [:]
        for unit in unitSnapshots where !FileValidation.isGeneratedFile(unit.mainFile) {
            let imports = try await extractor.imports(inFile: unit.mainFile)
            if !imports.isEmpty {
                mutableImportsByFile[unit.mainFile] = imports
            }
        }
        let importsByFile = mutableImportsByFile

        return try await withThrowingTaskGroup(of: (String, Set<String>)?.self) { group in
            for unit in unitSnapshots {
                group.addTask {
                    if FileValidation.isGeneratedFile(unit.mainFile) {
                        return nil
                    }

                    guard let imports = importsByFile[unit.mainFile],
                          !imports.isEmpty else {
                        return nil
                    }

                    let (referencedUSRs, _) = SymbolReferenceResolver.getReferenceUSRs(
                        mainFile: unit.mainFile,
                        occurrencesByFile: occurrencesByFile
                    )
                    var seenModules = Set<String>()
                    var requiredImports = Set<String>()

                    for moduleName in imports {
                        if requiredImports.contains(moduleName) {
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
                                    referencedUSRs.contains(occurrence.symbolUSR)
                                {
                                    requiredImports.insert(moduleName)
                                    break
                                }
                            }
                            if requiredImports.contains(moduleName) {
                                break
                            }
                        }
                        if hadOccurrences {
                            seenModules.insert(moduleName)
                        }
                    }

                    let missingModules = imports.subtracting(seenModules)
                    if !missingModules.isEmpty {
                        throw RemoveError.missingModuleInIndex(
                            file: unit.mainFile,
                            modules: missingModules
                        )
                    }

                    let unnecessary = imports
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
