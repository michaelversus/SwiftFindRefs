import Foundation

/// Detects unnecessary imports from an index store so callers can remove them.
protocol UnnecessaryAnalyzing {
    /// Examines `store` for redundant imports related to `indexStorePath` and returns them by file.
    ///
    /// - Parameters:
    ///   - store: The provider used to query symbols and references from the index store.
    ///   - indexStorePath: Filesystem path pointing to the index store under analysis.
    /// - Returns: A mapping from file paths to the set of modules that can be removed safely.
    /// - Throws: Errors encountered while reading or interpreting the index store data.
    func analyze(store: some IndexStoreProviding, indexStorePath: String) async throws -> [String: Set<String>]
}
