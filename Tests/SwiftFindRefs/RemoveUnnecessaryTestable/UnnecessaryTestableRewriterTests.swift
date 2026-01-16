import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryTestableRewriter Tests")
struct UnnecessaryTestableRewriterTests {
    @Test("rewrites @testable imports in-place")
    func test_rewritesTestableImports() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        let contents = """
        @testable import ModuleA
        import ModuleB
        @testable import ModuleC
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleA", "ModuleC"]])

        // Then
        #expect(updated == [filePath])
        let written = try #require(fileSystem.writtenFiles[filePath])
        #expect(written.contains("import ModuleA"))
        #expect(written.contains("import ModuleC"))
        #expect(!written.contains("@testable import ModuleA"))
        #expect(!written.contains("@testable import ModuleC"))
    }

    @Test("skips rewrite when no changes needed")
    func test_skipsRewriteWhenNoChanges() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        let contents = """
        import ModuleA
        import ModuleB
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleC"]])

        // Then
        #expect(updated.isEmpty)
        #expect(fileSystem.writtenFiles.isEmpty)
    }
}
