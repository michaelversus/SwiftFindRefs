import IndexStore

/// Defines a type that can collect index store units and their occurrence snapshots.
protocol IndexStoreCollecting {
    /// Scans the provided index store and returns all units alongside grouped occurrences.
    /// - Parameters:
    ///   - store: Index store abstraction to inspect.
    ///   - indexStorePath: File system path to the index store, used for error messages or logging.
    /// - Returns: A tuple containing the discovered units and a dictionary keyed by record name with their occurrence snapshots.
    static func collectUnitsAndRecords(
        from store: some IndexStoreProviding,
        indexStorePath: String
    ) throws -> ([UnitReaderProviding], [String: [OccurrenceSnapshot]])
}
