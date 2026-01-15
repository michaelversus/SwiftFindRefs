import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryTestableRemover Tests")
struct UnnecessaryTestableRemoverTests {
    @Test("run uses analyzer and rewriter and returns updated files")
    func test_run_UsesAnalyzerAndRewriter() async throws {
        // Given
        let indexStorePath = "/mock/index"
        let analyzer = MockAnalyzer(result: ["/mock/Test.swift": ["ModuleA"]])
        let rewriter = MockRewriter(result: ["/mock/Test.swift"])
        var messages: [String] = []
        let sut = UnnecessaryTestableRemover(
            indexStorePath: indexStorePath,
            print: { messages.append($0) },
            storeFactory: { DummyStore() },
            analyzer: analyzer,
            rewriter: rewriter
        )

        // When
        let result = try await sut.run()

        // Then
        #expect(result == ["/mock/Test.swift"])
        #expect(analyzer.calls == 1)
        #expect(analyzer.lastIndexStorePath == indexStorePath)
        #expect(rewriter.calls == 1)
        #expect(rewriter.lastRemovals == ["/mock/Test.swift": ["ModuleA"]])
        #expect(messages.contains("Removed unnecessary @testable imports from 1 files."))
    }

    @Test("run throws failedToOpenIndexStore when storeFactory throws")
    func test_run_WhenStoreFactoryThrows_throwsFailedToOpenIndexStore() async {
        // Given
        let indexStorePath = "/mock/index"
        let analyzer = MockAnalyzer(result: [:])
        let rewriter = MockRewriter(result: [])
        let sut = UnnecessaryTestableRemover(
            indexStorePath: indexStorePath,
            print: { _ in },
            storeFactory: { throw TestError.sample },
            analyzer: analyzer,
            rewriter: rewriter
        )

        // When
        let error = await #expect(throws: UnnecessaryTestableError.self) {
            _ = try await sut.run()
        }

        // Then
        guard case .failedToOpenIndexStore(let path) = error else {
            Issue.record("Expected failedToOpenIndexStore but got \(error)")
            return
        }
        #expect(path == indexStorePath)
        #expect(analyzer.calls == 0)
        #expect(rewriter.calls == 0)
    }
}

private enum TestError: Error {
    case sample
}

private struct DummyStore: IndexStoreProviding {
    func forEachUnit(_ callback: (UnitReaderProviding) -> Void) {
        _ = callback
    }

    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        _ = recordName
        return nil
    }
}

private final class MockAnalyzer: UnnecessaryTestableAnalyzing {
    private let result: [String: Set<String>]
    private(set) var calls = 0
    private(set) var lastIndexStorePath: String?

    init(result: [String: Set<String>]) {
        self.result = result
    }

    func analyze(store: some IndexStoreProviding, indexStorePath: String) async throws -> [String: Set<String>] {
        _ = store
        calls += 1
        lastIndexStorePath = indexStorePath
        return result
    }
}

private final class MockRewriter: UnnecessaryTestableRewriting {
    private let result: [String]
    private(set) var calls = 0
    private(set) var lastRemovals: [String: Set<String>]?

    init(result: [String]) {
        self.result = result
    }

    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String] {
        calls += 1
        lastRemovals = removalsByFile
        return result
    }
}
