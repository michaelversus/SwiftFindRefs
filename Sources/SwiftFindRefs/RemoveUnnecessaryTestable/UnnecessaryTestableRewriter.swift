import Foundation

/// Rewrites source files by dropping optional `@testable` imports that no longer have references.
struct UnnecessaryTestableRewriter: UnnecessaryRewriting {
    private let fileSystem: FileSystemProvider
    private let print: (String) -> Void

    /// Creates a rewriter that uses the provided file system abstraction and logger.
    init(fileSystem: FileSystemProvider, print: @escaping (String) -> Void) {
        self.fileSystem = fileSystem
        self.print = print
    }

    /// Applies the computed removals to the matching files, rewriting `@testable` imports to standard imports.
    ///
    /// - Parameter removalsByFile: Files mapped to the modules whose `@testable` imports should be downgraded.
    /// - Returns: The list of files that were updated by the rewrite.
    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String] {
        let fileSystem = FileSystemBox(fileSystem: self.fileSystem)
        let print = PrintBox(print: self.print)
        print.print("Removing unnecessary @testable imports for \(removalsByFile.count) files...")

        return try await withThrowingTaskGroup(of: String?.self) { group in
            for (filePath, modules) in removalsByFile {
                group.addTask {
                    let lines = try fileSystem.fileSystem.readLines(atPath: filePath)
                    if let updated = Self.replaceTestableImports(in: lines, modules: modules) {
                        try fileSystem.fileSystem.writeFile(updated, toPath: filePath)
                        return filePath
                    }
                    return nil
                }
            }

            var updatedFiles: [String] = []
            for try await result in group {
                if let filePath = result {
                    updatedFiles.append(filePath)
                }
            }
            return updatedFiles
        }
    }

    /// Downgrades any matching `@testable import` lines to plain `import` lines for the provided modules.
    ///
    /// - Parameters:
    ///   - lines: The file contents split into lines.
    ///   - modules: The modules whose `@testable` imports should be rewritten.
    /// - Returns: The rewritten file joined by newline characters, or `nil` when no updates were needed.
    private static func replaceTestableImports(in lines: [String], modules: Set<String>) -> String? {
        let prefix = "@testable import "
        var updatedLines: [String]? = nil

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) else {
                continue
            }
            let moduleName = String(trimmed.dropFirst(prefix.count))
            guard modules.contains(moduleName) else {
                continue
            }
            if updatedLines == nil {
                updatedLines = lines
            }
            let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
            updatedLines?[index] = "\(leadingWhitespace)import \(moduleName)"
        }

        return updatedLines?.joined(separator: "\n")
    }
}
