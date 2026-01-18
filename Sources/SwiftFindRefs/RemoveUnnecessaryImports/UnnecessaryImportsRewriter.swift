import Foundation

/// Applies the discovered unused import information by editing source files accordingly.
struct UnnecessaryImportsRewriter: UnnecessaryRewriting {
    private let fileSystem: FileSystemProvider
    private let print: (String) -> Void

    /// Creates a rewriter that operates through the provided file system and logging callback.
    init(fileSystem: FileSystemProvider, print: @escaping (String) -> Void) {
        self.fileSystem = fileSystem
        self.print = print
    }

    /// Removes the unused imports for each file and reports which files were modified.
    ///
    /// - Parameter removalsByFile: Files mapped to the set of module imports that can be removed.
    /// - Returns: The list of file paths that were updated.
    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String] {
        let fileSystem = FileSystemBox(fileSystem: self.fileSystem)
        let print = PrintBox(print: self.print)
        print.print("Removing unused imports for \(removalsByFile.count) files...")

        return try await withThrowingTaskGroup(of: String?.self) { group in
            for (filePath, modules) in removalsByFile {
                group.addTask {
                    let lines = try fileSystem.fileSystem.readLines(atPath: filePath)
                    if let updated = Self.replaceUnusedImports(in: lines, modules: modules) {
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

    /// Filters import statements to remove modules that no longer have references.
    ///
    /// - Parameters:
    ///   - lines: The source file split into lines.
    ///   - modules: The set of module names that should be retained as unused imports.
    /// - Returns: The updated file body if removals occurred; otherwise `nil`.
    private static func replaceUnusedImports(in lines: [String], modules: Set<String>) -> String? {
        var retainedLines: [String] = []
        var hasChanges = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let prefix: String

            if trimmed.hasPrefix("@testable import ") {
                prefix = "@testable import "
            } else if trimmed.hasPrefix("import ") {
                prefix = "import "
            } else {
                retainedLines.append(line)
                continue
            }

            let suffix = trimmed.dropFirst(prefix.count)
            // Capture contiguous non-whitespace characters (stopping at a slash) to isolate the module identifier.
            // Examples: `import Networking//comment` keeps `Networking`, `import Foundation  // note` keeps `Foundation`.
            let moduleName = String(suffix.prefix { !$0.isWhitespace && $0 != "/" })
            guard !moduleName.isEmpty else {
                retainedLines.append(line)
                continue
            }

            if modules.contains(moduleName) {
                retainedLines.append(line)
                continue
            }

            hasChanges = true
        }

        return hasChanges ? retainedLines.joined(separator: "\n") : nil
    }
}
