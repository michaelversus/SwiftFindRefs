/// Simple facade that captures the ability to remove unnecessary imports.
protocol UnnecessaryRemoving {
    /// Performs the removal operation and returns the updated files.
    func run() async throws -> [String]
}
