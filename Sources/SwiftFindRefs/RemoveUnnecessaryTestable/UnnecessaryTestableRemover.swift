import Foundation
@preconcurrency import IndexStore

struct UnnecessaryTestableRemover {
    let indexStorePath: String
    let print: (String) -> Void
    private let storeFactory: () throws -> IndexStoreProviding
    private let analyzer: UnnecessaryTestableAnalyzing
    private let rewriter: UnnecessaryTestableRewriting

    init(
        indexStorePath: String,
        print: @escaping (String) -> Void,
        storeFactory: @escaping () throws -> IndexStoreProviding,
        analyzer: UnnecessaryTestableAnalyzing,
        rewriter: UnnecessaryTestableRewriting
    ) {
        self.indexStorePath = indexStorePath
        self.print = print
        self.storeFactory = storeFactory
        self.analyzer = analyzer
        self.rewriter = rewriter
    }

    func run() async throws -> [String] {
        let store: IndexStoreProviding
        do {
            store = try storeFactory()
        } catch {
            throw UnnecessaryTestableError.failedToOpenIndexStore(indexStorePath)
        }

        let removalsByFile = try await analyzer.analyze(store: store, indexStorePath: indexStorePath)
        guard !removalsByFile.isEmpty else {
            return []
        }
        print("Planning to remove unnecessary @testable imports from \(removalsByFile.count) files.")
        let updatedFiles = try await rewriter.rewriteFiles(removalsByFile)
        print("Removed unnecessary @testable imports from \(updatedFiles.count) files.")
        return updatedFiles
    }
}

protocol UnnecessaryTestableRemoving {
    func run() async throws -> [String]
}

extension UnnecessaryTestableRemover: UnnecessaryTestableRemoving {}
