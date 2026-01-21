import Foundation

/// Analyzes an IndexStoreDB to identify  unused imports or unnecessary @testable imports in Swift source files.
protocol UnnecessaryAnalyzing {
    /// Examines IndexStoreDB for unused imports or unnecessary @testable imports related to an indexStorePath and returns them by file.
    ///
    /// - Parameters:
    /// - Returns: A mapping from file paths to the set of modules that can be removed safely.
    /// - Throws: Errors encountered while reading or interpreting the index store data.
    func analyze() async throws -> [String: Set<String>]
}
