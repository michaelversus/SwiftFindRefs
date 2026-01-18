/// Enumerates the modules imported with `@testable` or plain imports in a Swift source file.
///
/// Implementations handle whatever file I/O or parsing is required and therefore may throw.
protocol ImportExtracting {
    /// Returns the set of module names that are imported with `@testable` or not in the provided file.
    ///
    /// - Parameter path: The file system path to inspect for `@testable` or not imports.
    /// - Returns: A set of module names that are imported with the `@testable` attribute or all .
    /// - Throws: Errors encountered while reading or analyzing the file.
    func imports(inFile path: String) async throws -> Set<String>
}
