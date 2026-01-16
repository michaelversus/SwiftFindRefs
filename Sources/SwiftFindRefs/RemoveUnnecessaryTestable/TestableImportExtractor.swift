import Foundation

struct TestableImportExtractor: TestableImportExtracting {
    private let fileSystem: FileSystemProvider
    private let excludeCompilationConditionals: Bool
    private let testablePrefix = "@testable import "

    init(
        fileSystem: FileSystemProvider,
        excludeCompilationConditionals: Bool
    ) {
        self.fileSystem = fileSystem
        self.excludeCompilationConditionals = excludeCompilationConditionals
    }

    func testableImports(inFile path: String) async throws -> Set<String> {
        let lines = try await fileSystem.readLines(atPath: path)
        var testableImports = Set<String>()
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

            if trimmed.hasPrefix(testablePrefix) {
                if excludeCompilationConditionals && conditionalDepth > 0 {
                    continue
                }
                let modulePart = trimmed.dropFirst(testablePrefix.count)
                let moduleName = modulePart.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "." }).first
                if let moduleName {
                    testableImports.insert(String(moduleName))
                }
            }
        }

        return testableImports
    }
}
