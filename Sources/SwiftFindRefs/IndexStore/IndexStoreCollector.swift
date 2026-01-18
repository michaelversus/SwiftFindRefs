import IndexStore

enum IndexStoreCollector: IndexStoreCollecting {
    static func collectUnitsAndRecords(
        from store: some IndexStoreProviding,
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
            throw RemoveError.failedToLoadUnits(indexStorePath)
        }

        return (units, occurrencesByFile)
    }
}
