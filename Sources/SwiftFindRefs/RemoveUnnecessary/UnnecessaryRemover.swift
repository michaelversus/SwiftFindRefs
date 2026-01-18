import Foundation
@preconcurrency import IndexStore

/// Removes unnecessary imports by analyzing an index store and rewriting affected source files.
struct UnnecessaryRemover {
    let indexStorePath: String
    let print: (String) -> Void
    private let storeFactory: () throws -> IndexStoreProviding
    private let analyzer: UnnecessaryAnalyzing
    private let rewriter: UnnecessaryRewriting
    private let mode: Mode

    /// Indicates whether only `@testable` imports or all imports should be removed.
    enum Mode {
        case testableImports
        case imports
    }

    /// Creates a remover configured with its dependencies and desired removal strategy.
    ///
    /// - Parameters:
    ///   - indexStorePath: The file system location of the index store to inspect.
    ///   - print: Closure used to emit progress messages to the caller.
    ///   - storeFactory: Factory that opens an `IndexStoreProviding` instance on demand.
    ///   - analyzer: Component that identifies unnecessary imports per file.
    ///   - rewriter: Component that rewrites source files to remove the flagged imports.
    ///   - mode: Specifies whether to target only `@testable` imports or all imports.
    init(
        indexStorePath: String,
        print: @escaping (String) -> Void,
        storeFactory: @escaping () throws -> IndexStoreProviding,
        analyzer: UnnecessaryAnalyzing,
        rewriter: UnnecessaryRewriting,
        mode: Mode
    ) {
        self.indexStorePath = indexStorePath
        self.print = print
        self.storeFactory = storeFactory
        self.analyzer = analyzer
        self.rewriter = rewriter
        self.mode = mode
    }

    /// Executes the workflow that removes unnecessary imports and reports the updated files.
    ///
    /// - Returns: The list of files that were rewritten.
    /// - Throws: Any error that occurs while opening the index store, analyzing removals, or rewriting files.
    func run() async throws -> [String] {
        let store: IndexStoreProviding
        do {
            store = try storeFactory()
        } catch {
            throw RemoveError.failedToOpenIndexStore(indexStorePath)
        }
        let removalsByFile = try await analyzer.analyze(store: store, indexStorePath: indexStorePath)
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

/// Simple facade that captures the ability to remove unnecessary imports.
protocol UnnecessaryRemoving {
    /// Performs the removal operation and returns the updated files.
    func run() async throws -> [String]
}

extension UnnecessaryRemover: UnnecessaryRemoving {}
