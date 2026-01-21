import Foundation
@preconcurrency import IndexStore

/// Removes unnecessary imports by analyzing an index store and rewriting affected source files.
struct UnnecessaryRemover: UnnecessaryRemoving {
    let print: (String) -> Void
    private let analyzer: any UnnecessaryAnalyzing
    private let rewriter: any UnnecessaryRewriting
    private let mode: Mode

    /// Indicates whether only `@testable` imports or all imports should be removed.
    enum Mode {
        case testableImports
        case imports
    }

    /// Creates a remover configured with its dependencies and desired removal strategy.
    ///
    /// - Parameters:
    ///   - print: Closure used to emit progress messages to the caller.
    ///   - analyzer: Component that identifies unnecessary imports per file.
    ///   - rewriter: Component that rewrites source files to remove the flagged imports.
    ///   - mode: Specifies whether to target only `@testable` imports or all imports.
    init(
        print: @escaping (String) -> Void,
        analyzer: any UnnecessaryAnalyzing,
        rewriter: any UnnecessaryRewriting,
        mode: Mode
    ) {
        self.print = print
        self.analyzer = analyzer
        self.rewriter = rewriter
        self.mode = mode
    }

    /// Executes the workflow that removes unnecessary imports and reports the updated files.
    ///
    /// - Returns: The list of files that were rewritten.
    /// - Throws: Any error that occurs while opening the index store, analyzing removals, or rewriting files.
    func run() async throws -> [String] {
        let removalsByFile = try await analyzer.analyze()
        guard !removalsByFile.isEmpty else {
            return []
        }
        let testableText: String = mode == .testableImports ? "@testable" : ""
        print("Planning to remove unnecessary \(testableText) imports from \(removalsByFile.count) files.")
        let updatedFiles = try await rewriter.rewriteFiles(removalsByFile)
        print("Removed unnecessary \(testableText) imports from \(updatedFiles.count) files.")
        return updatedFiles
    }
}
