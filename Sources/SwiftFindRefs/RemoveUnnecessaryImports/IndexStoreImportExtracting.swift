/// Extracts imported module names by using IndexStore occurrences that point at `import` statements.
///
/// This extractor is intentionally pure and synchronous to make it easy to unit test.
protocol IndexStoreImportExtracting {
    /// Returns module names imported in a given source file.
    ///
    /// - Parameters:
    ///   - mainFile: The file to extract import statements from.
    ///   - occurrencesByFile: Mapping of file paths to symbol occurrences for that file.
    ///   - fileLines: The file contents split by line (1 line per element).
    ///   - allModuleNames: All module names present in the index store (used for filtering).
    ///   - ignoredModules: Module names that should not be considered.
    func imports(
        inMainFile mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]],
        fileLines: [String],
        allModuleNames: Set<String>,
        ignoredModules: Set<String>
    ) -> Set<String>
}
