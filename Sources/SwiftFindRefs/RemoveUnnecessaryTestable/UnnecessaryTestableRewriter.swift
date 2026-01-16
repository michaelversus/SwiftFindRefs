import Foundation

struct UnnecessaryTestableRewriter: UnnecessaryTestableRewriting {
    private let fileSystem: FileSystemProvider
    private let print: (String) -> Void

    init(fileSystem: FileSystemProvider, print: @escaping (String) -> Void) {
        self.fileSystem = fileSystem
        self.print = print
    }

    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String] {
        let fileSystem = FileSystemBox(fileSystem: self.fileSystem)
        let print = PrintBox(print: self.print)
        print.print("Rewriting files: \(removalsByFile.count)")

        return try await withThrowingTaskGroup(of: String?.self) { group in
            for (filePath, modules) in removalsByFile {
                group.addTask {
                    let lines = try await fileSystem.fileSystem.readLines(atPath: filePath)
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

// MARK: - Sendable wrappers

private struct FileSystemBox: @unchecked Sendable {
    // FileManager is thread-safe for concurrent reads/writes to different files.
    let fileSystem: FileSystemProvider
}

private struct PrintBox: @unchecked Sendable {
    // Printing is treated as fire-and-forget logging for parallel tasks.
    let print: (String) -> Void
}
