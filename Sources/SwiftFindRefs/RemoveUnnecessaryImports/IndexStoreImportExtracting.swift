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
    ///   - ignoredModules: Module names that should not be considered.
    /// - Returns: All imported module names found in the file, including system frameworks.
    func imports(
        inMainFile mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]],
        fileLines: [String],
        ignoredModules: Set<String>,
        vPrint: ((String) -> Void)?
    ) -> Set<String>
    
    /// Returns a mapping of import lines to their specific symbol names (if any).
    /// For specific imports like `import struct Module.SomeStruct`, returns the symbol name.
    /// For regular imports, returns nil.
    ///
    /// - Parameters:
    ///   - mainFile: The file to extract import statements from.
    ///   - fileLines: The file contents split by line (1 line per element).
    /// - Returns: Mapping of full import line to optional specific symbol name.
    func specificImports(
        inMainFile mainFile: String,
        fileLines: [String]
    ) -> [String: String?]
}
