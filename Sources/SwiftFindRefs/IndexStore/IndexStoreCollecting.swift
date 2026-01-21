import IndexStore

/// Defines a type that can collect index store units and their occurrence snapshots.
protocol IndexStoreCollecting {
    /// Scans the provided index store and returns all units alongside grouped occurrences.
    /// - Returns: A tuple containing the discovered units and a dictionary keyed by record name with their occurrence snapshots.
    /// - Throws: Errors encountered while reading units or occurrences from the index store.
    func collectUnitsAndRecords() throws -> ([UnitReaderProviding], [String: [OccurrenceSnapshot]])
}
