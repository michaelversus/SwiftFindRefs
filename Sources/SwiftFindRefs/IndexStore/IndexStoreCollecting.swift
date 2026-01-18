import IndexStore

protocol IndexStoreCollecting {
    static func collectUnitsAndRecords(
        from store: some IndexStoreProviding,
        indexStorePath: String
    ) throws -> ([UnitReaderProviding], [String: [OccurrenceSnapshot]])
}
