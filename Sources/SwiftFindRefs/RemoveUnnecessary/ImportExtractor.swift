import Foundation

/// Reads a source file and returns the module names that match the configured import prefix.
///
/// The extractor can optionally ignore imports that are nested inside conditional compilation
/// blocks (anything between `#if` and `#endif`). It can also filter out module names listed in
/// `ignoredModules`.
///
/// If an import line ends with the marker `// @ignore-import`, that import is skipped.
struct ImportExtractor: ImportExtracting {
    private let fileSystem: FileSystemProvider
    private let excludeCompilationConditionals: Bool

    /// Module names that should be ignored even if they appear in the file.
    ///
    /// Matching is done using exact string equality.
    let ignoredModules: [String]

    /// Prefix that determines which import declarations should be collected.
    let prefix: Prefix

    /// The import prefixes that the extractor understands.
    enum Prefix: String {
        /// Prefix that identifies `@testable` imports.
        case testableImport = "@testable import "
        /// Prefix that identifies regular imports.
        case regularImport = "import "
    }

    /// Initializes the extractor with its dependencies and runtime options.
    ///
    /// - Parameters:
    ///   - fileSystem: The provider used to read files from disk.
    ///   - excludeCompilationConditionals: Whether to ignore matching imports nested inside `#if` blocks.
    ///   - ignoredModules: Import module names that should be excluded from the returned set.
    ///   - prefix: The textual prefix that should be looked for when parsing each line in the file.
    init(
        fileSystem: FileSystemProvider,
        excludeCompilationConditionals: Bool,
        ignoredModules: [String],
        prefix: Prefix
    ) {
        self.fileSystem = fileSystem
        self.excludeCompilationConditionals = excludeCompilationConditionals
        self.ignoredModules = ignoredModules
        self.prefix = prefix
    }

    /// Publishes the module names imported with the configured prefix in `path`.
    ///
    /// The extractor considers only lines whose *trimmed* content starts with `prefix`.
    /// Module names are extracted by taking the first token after the prefix, splitting on
    /// whitespace and `.` (for example, `import Foo.Bar` produces `Foo`).
    ///
    /// If the original line ends with `// @ignore-import`, that import is skipped.
    ///
    /// - Parameter path: File system path to inspect for matching imports.
    /// - Returns: A set of module names parsed from the matching import declarations.
    /// - Throws: Any error produced while reading the file or analyzing its contents.
    func imports(inFile path: String) async throws -> Set<String> {
        let lines = try fileSystem.readLines(atPath: path)
        var imports = Set<String>()
        var conditionalDepth = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if") {
                conditionalDepth += 1
                continue
            }
            if trimmed.hasPrefix("#elseif") || trimmed.hasPrefix("#else") {
                continue
            }
            if trimmed.hasPrefix("#endif") {
                conditionalDepth = max(0, conditionalDepth - 1)
                continue
            }
            if trimmed.hasPrefix(prefix.rawValue) {
                if excludeCompilationConditionals && conditionalDepth > 0 {
                    continue
                }

                // Ignores an import if the original line ends with: `// @ignore-import`.
                let ignoreRegex = try! Regex(#"// *@ignore-import$"#)
                if line.firstMatch(of: ignoreRegex) != nil {
                    continue
                }

                let modulePart = trimmed.dropFirst(prefix.rawValue.count)
                let moduleName = modulePart.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "." }).first
                guard let moduleName else { continue }
                let moduleNameString = String(moduleName)
                guard !ignoredModules.contains(moduleNameString) else { continue }
                imports.insert(moduleNameString)
            }
        }
        return imports
    }
}
