import Foundation
@preconcurrency import IndexStore

struct UnnecessaryRemover {
    let indexStorePath: String
    let print: (String) -> Void
    private let storeFactory: () throws -> IndexStoreProviding
    private let analyzer: UnnecessaryAnalyzing
    private let rewriter: UnnecessaryRewriting
    private let mode: Mode

    enum Mode {
        case testableImports
        case imports
    }

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

protocol UnnecessaryRemoving {
    func run() async throws -> [String]
}

extension UnnecessaryRemover: UnnecessaryRemoving {}
