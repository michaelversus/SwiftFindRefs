import Foundation

/// Rewrites source files to drop the imports identified as unnecessary.
protocol UnnecessaryRewriting {
    /// Rewrites the files described in `removalsByFile`, returning the paths that were updated.
    ///
    /// - Parameter removalsByFile: Maps each file path to the modules that should be removed from it.
    /// - Returns: The list of files that were rewritten.
    /// - Throws: Any errors encountered while reading or writing the affected files.
    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String]
}
