import Foundation
@preconcurrency import IndexStore

struct UnnecessaryTestableAnalyzer: UnnecessaryTestableAnalyzing {
    private let fileSystem: FileSystemProvider
    private let extractor: TestableImportExtracting

    init(
        fileSystem: FileSystemProvider,
        extractor: TestableImportExtracting,
    ) {
        self.fileSystem = fileSystem
        self.extractor = extractor
    }

    func analyze(store: some IndexStoreProviding, indexStorePath: String) async throws -> [String: Set<String>] {
        let (units, occurrencesByFile) = try collectUnitsAndRecords(store: store, indexStorePath: indexStorePath)
        let unitSnapshots = units.map { UnitSnapshot(mainFile: $0.mainFile, moduleName: $0.moduleName) }
        let unitsByModule = Dictionary(grouping: unitSnapshots, by: \.moduleName)
        let fileSystemBox = FileSystemBox(fileSystem: fileSystem)
        let fileLinesCache = FileLinesCache(
            readLines: { path in
                try await fileSystemBox.fileSystem.readLines(atPath: path)
            }
        )
        var mutableTestableImportsByFile: [String: Set<String>] = [:]
        for unit in unitSnapshots where !Self.isGeneratedFile(unit.mainFile) {
            let testableImports = try await extractor.testableImports(inFile: unit.mainFile)
            if !testableImports.isEmpty {
                mutableTestableImportsByFile[unit.mainFile] = testableImports
            }
        }
        let testableImportsByFile = mutableTestableImportsByFile

        return try await withThrowingTaskGroup(of: (String, Set<String>)?.self) { group in
            for unit in unitSnapshots {
                group.addTask {
                    if Self.isGeneratedFile(unit.mainFile) {
                        return nil
                    }

                    guard let testableImports = testableImportsByFile[unit.mainFile],
                          !testableImports.isEmpty else {
                        return nil
                    }

                    let (referencedUSRs, overrideUSRs) = Self.getReferenceUSRs(
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
                        throw UnnecessaryTestableError.missingModuleInIndex(
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

    private static func getReferenceUSRs(
        mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]]
    ) -> (Set<String>, Set<String>) {
        guard let occurrences = occurrencesByFile[mainFile] else {
            return ([], [])
        }

        var usrs = Set<String>()
        var overrideUSRs = Set<String>()
        for occurrence in occurrences {
            if occurrence.roles.contains(.reference) {
                usrs.insert(occurrence.symbolUSR)
                if occurrence.roles.contains(.overrideOf) || occurrence.roles.contains(.baseOf) {
                    overrideUSRs.insert(occurrence.symbolUSR)
                }
            }
        }

        return (usrs, overrideUSRs)
    }

    private func collectUnitsAndRecords(
        store: some IndexStoreProviding,
        indexStorePath: String
    ) throws -> ([UnitReaderProviding], [String: [OccurrenceSnapshot]]) {
        var units: [UnitReaderProviding] = []
        var occurrencesByFile: [String: [OccurrenceSnapshot]] = [:]
        store.forEachUnit { unitReader in
            if unitReader.mainFile.isEmpty {
                return
            }

            units.append(unitReader)
            if let recordName = unitReader.recordName,
               let recordReader = try? store.recordReader(for: recordName) {
                // IndexStore can return multiple units for the same file (e.g. multiple targets);
                // keep the first record to avoid failing when duplicates exist.
                if occurrencesByFile[unitReader.mainFile] == nil {
                    var occurrences: [OccurrenceSnapshot] = []
                    recordReader.forEachOccurrence { occurrence in
                        var relatedSymbols: [RelatedSymbolSnapshot] = []
                        occurrence.forEachRelatedSymbol { symbol, roles in
                            relatedSymbols.append(
                                RelatedSymbolSnapshot(kind: symbol.kind, roles: roles)
                            )
                        }
                        occurrences.append(
                            OccurrenceSnapshot(
                                symbolKind: occurrence.symbolMatching.kind,
                                roles: occurrence.roles,
                                locationLine: occurrence.locationLine,
                                symbolUSR: occurrence.symbolUSR,
                                relatedSymbols: relatedSymbols
                            )
                        )
                    }
                    occurrencesByFile[unitReader.mainFile] = occurrences
                }
            }
        }

        guard !units.isEmpty else {
            throw UnnecessaryTestableError.failedToLoadUnits(indexStorePath)
        }

        return (units, occurrencesByFile)
    }

    private static func isGeneratedFile(_ path: String) -> Bool {
        path.hasSuffix(".generated.swift")
    }

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

    private static func isGetterOrSetterFunction(occurrence: OccurrenceSnapshot) -> Bool {
        let functionTypes: [SymbolKind] = [.classMethod, .instanceMethod, .staticMethod]
        guard functionTypes.contains(occurrence.symbolKind) else {
            return false
        }
        return occurrence.roles.contains(.accessorOf)
    }
}

private struct OccurrenceSnapshot: Sendable {
    let symbolKind: SymbolKind
    let roles: SymbolRoles
    let locationLine: Int
    let symbolUSR: String
    let relatedSymbols: [RelatedSymbolSnapshot]
}

private struct UnitSnapshot: Sendable {
    let mainFile: String
    let moduleName: String
}

private struct RelatedSymbolSnapshot: Sendable {
    let kind: SymbolKind
    let roles: SymbolRoles
}

private actor FileLinesCache {
    private var cache: [String: [String]] = [:]
    private let readLines: @Sendable (String) async throws -> [String]

    init(
        readLines: @escaping @Sendable (String) async throws -> [String]
    ) {
        self.readLines = readLines
    }

    func lines(for file: String) async -> [String] {
        if let cached = cache[file] {
            return cached
        }
        let lines = (try? await readLines(file)) ?? []
        cache[file] = lines
        return lines
    }
}

private struct FileSystemBox: @unchecked Sendable {
    // FileManager is thread-safe for concurrent reads across different files.
    let fileSystem: FileSystemProvider
}
