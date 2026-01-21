import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryRemover Tests")
struct UnnecessaryRemoverTests {
    @Test("run uses analyzer and rewriter and returns updated files")
    func test_run_UsesAnalyzerAndRewriter() async throws {
        // Given
        let analyzer = MockAnalyzer(result: ["/mock/Test.swift": ["ModuleA"]])
        let rewriter = MockRewriter(result: ["/mock/Test.swift"])
        var messages: [String] = []
        let sut = UnnecessaryRemover(
            print: { messages.append($0) },
            analyzer: analyzer,
            rewriter: rewriter,
            mode: .testableImports
        )

        // When
        let result = try await sut.run()

        // Then
        #expect(result == ["/mock/Test.swift"])
        #expect(analyzer.calls == 1)
        #expect(rewriter.actions == [.rewriteFiles(removalsByFile: ["/mock/Test.swift": ["ModuleA"]])])
        #expect(messages.contains("Removed unnecessary @testable imports from 1 files."))
    }

    @Test("run returns empty array when there are no removals")
    func test_run_WhenAnalyzerReturnsNoRemovals_ReturnsEmptyArray() async throws {
        // Given
        let analyzer = MockAnalyzer(result: [:])
        let rewriter = MockRewriter(result: ["/mock/ShouldNotBeCalled.swift"])
        var messages: [String] = []
        let sut = UnnecessaryRemover(
            print: { messages.append($0) },
            analyzer: analyzer,
            rewriter: rewriter,
            mode: .testableImports
        )

        // When
        let result = try await sut.run()

        // Then
        #expect(result.isEmpty)
        #expect(analyzer.calls == 1)
        #expect(rewriter.actions.isEmpty)
        #expect(messages.isEmpty)
    }

    @Test("run in regular imports mode omits @testable in messages")
    func test_run_WhenModeIsRegularImports_OmitsTestableTextFromMessages() async throws {
        // Given
        let analyzer = MockAnalyzer(result: ["/mock/Test.swift": ["ModuleA"]])
        let rewriter = MockRewriter(result: ["/mock/Test.swift"])
        var messages: [String] = []
        let sut = UnnecessaryRemover(
            print: { messages.append($0) },
            analyzer: analyzer,
            rewriter: rewriter,
            mode: .imports
        )

        // When
        let result = try await sut.run()

        // Then
        #expect(result == ["/mock/Test.swift"])
        #expect(analyzer.calls == 1)
        #expect(rewriter.actions == [.rewriteFiles(removalsByFile: ["/mock/Test.swift": ["ModuleA"]])])
        #expect(messages.count == 2)
        #expect(messages.contains(where: { $0.contains("@testable") }) == false)
    }
}
