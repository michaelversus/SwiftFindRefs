import Foundation

/// Reads a source file and returns the module names that match the configured import prefix.
///
/// The extractor honors the `excludeCompilationConditionals` flag to skip imports that are
/// guarded by `#if` blocks when the caller does not want them counted.
struct ImportExtractor: ImportExtracting {
    private let fileSystem: FileSystemProvider
    private let excludeCompilationConditionals: Bool
    private let prefix: Prefix

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
    ///   - excludeCompilationConditionals: Whether to ignore imports nested inside `#if` blocks.
    ///   - prefix: The prefix that should be looked for when parsing each line in the file.
    init(
        fileSystem: FileSystemProvider,
        excludeCompilationConditionals: Bool,
        prefix: Prefix
    ) {
        self.fileSystem = fileSystem
        self.excludeCompilationConditionals = excludeCompilationConditionals
        self.prefix = prefix
    }

    /// Publishes the module names imported with the configured prefix in `path`.
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
                let modulePart = trimmed.dropFirst(prefix.rawValue.count)
                let moduleName = modulePart.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "." }).first
                if let moduleName {
                    imports.insert(String(moduleName))
                }
            }
        }
        return imports
    }
}
