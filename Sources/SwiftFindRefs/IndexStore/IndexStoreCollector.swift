import IndexStore

/// Concrete collector that walks an IndexStore and extracts unit readers and occurrence snapshots.
struct IndexStoreCollector: IndexStoreCollecting {
    private let store: any IndexStoreProviding
    private let indexStorePath: String

    /// Initializes the collector with the specified index store and its file system path.
    /// - Parameters:
    ///  - store: The index store abstraction to inspect.
    ///  - indexStorePath: Path to the IndexStore, used for error reporting when units cannot be loaded.
    init(store: some IndexStoreProviding, indexStorePath: String) {
        self.store = store
        self.indexStorePath = indexStorePath
    }

    /// Scans the provided store, gathering unit readers and their occurrences grouped by main file.
    /// - Returns: A tuple containing collected unit readers and a dictionary of occurrence snapshots keyed by file path.
    /// - Throws: `RemoveError.failedToLoadUnits` when the store yields no units.
    func collectUnitsAndRecords() throws -> ([UnitReaderProviding], [String: [OccurrenceSnapshot]]) {
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
                                locationColumn: occurrence.locationColumn,
                                symbolUSR: occurrence.symbolUSR,
                                symbolName: occurrence.symbolMatching.name,
                                relatedSymbols: relatedSymbols
                            )
                        )
                    }
                    occurrencesByFile[unitReader.mainFile] = occurrences
                }
            }
        }

        guard !units.isEmpty else {
            throw RemoveError.failedToLoadUnits(indexStorePath)
        }

        return (units, occurrencesByFile)
    }
}
