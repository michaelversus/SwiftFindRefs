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
            
            // Parse module name, handling specific imports like `import struct Module.Symbol`
            let specificImportKeywords = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
            let parts = suffix.split(whereSeparator: { $0 == " " || $0 == "\t" })
            
            let moduleName: String
            if let firstPart = parts.first,
               specificImportKeywords.contains(String(firstPart)),
               parts.count >= 2 {
                // Specific import: import struct Module.Symbol
                // Extract module name from "Module.Symbol" part
                let moduleAndSymbol = String(parts[1])
                if let dotIndex = moduleAndSymbol.firstIndex(of: ".") {
                    moduleName = String(moduleAndSymbol[..<dotIndex])
                } else {
                    // No dot, so the second part is the module name
                    moduleName = moduleAndSymbol
                }
            } else if let firstPart = parts.first {
                // Regular import: import Module
                // Capture contiguous non-whitespace characters (stopping at a slash) to isolate the module identifier.
                // Examples: `import Networking//comment` keeps `Networking`, `import Foundation  // note` keeps `Foundation`.
                moduleName = String(firstPart.prefix { !$0.isWhitespace && $0 != "/" })
            } else {
                // Can't parse, keep the import to be safe
                retainedLines.append(line)
                continue
            }
            
            guard !moduleName.isEmpty else {
                retainedLines.append(line)
                continue
            }

            // Only remove imports that are in the modules set (unnecessary imports)
            // Note: The analyzer already verified that specific imports with used symbols are not in this set
            if modules.contains(moduleName) {
                hasChanges = true
                continue  // Skip this line (remove the import)
            }

            // Retain imports that are NOT in the modules set (necessary imports)
            retainedLines.append(line)
        }

        return hasChanges ? retainedLines.joined(separator: "\n") : nil
    }
}
