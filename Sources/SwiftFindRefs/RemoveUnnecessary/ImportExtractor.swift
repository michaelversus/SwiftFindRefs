import Foundation

struct ImportExtractor: ImportExtracting {
    private let fileSystem: FileSystemProvider
    private let excludeCompilationConditionals: Bool
    private let prefix: Prefix

    enum Prefix: String {
        case testableImport = "@testable import "
        case regularImport = "import "
    }

    init(
        fileSystem: FileSystemProvider,
        excludeCompilationConditionals: Bool,
        prefix: Prefix
    ) {
        self.fileSystem = fileSystem
        self.excludeCompilationConditionals = excludeCompilationConditionals
        self.prefix = prefix
    }

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
