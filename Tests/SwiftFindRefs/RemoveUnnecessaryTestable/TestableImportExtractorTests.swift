import Testing
@testable import SwiftFindRefs

@Suite("TestableImportExtractor Tests")
struct TestableImportExtractorTests {
    @Test("extracts @testable imports from file")
    func test_extractsTestableImports() async throws {
        // Given
        let filePath = "/mock/test.swift"
        let contents = """
        import Foundation
        @testable import ModuleA
        @testable import ModuleB
        import ModuleC
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = TestableImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false
        )

        // When
        let imports = try await sut.testableImports(inFile: filePath)

        // Then
        #expect(imports == ["ModuleA", "ModuleB"])
    }

    @Test("excludes @testable imports inside compilation conditionals when enabled")
    func test_excludesConditionalTestableImports() async throws {
        // Given
        let filePath = "/mock/conditional.swift"
        let contents = """
        #if Stoiximan
        @testable import Stoiximan
        #elseif Betano
        @testable import Betano
        #else
        @testable import BetanoCasinoBE
        #endif
        @testable import AlwaysIncluded
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = TestableImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: true
        )

        // When
        let imports = try await sut.testableImports(inFile: filePath)

        // Then
        #expect(imports == ["AlwaysIncluded"])
    }

    @Test("includes @testable imports inside compilation conditionals when disabled")
    func test_includesConditionalTestableImportsWhenDisabled() async throws {
        // Given
        let filePath = "/mock/conditional.swift"
        let contents = """
        #if Stoiximan
        @testable import Stoiximan
        #elseif Betano
        @testable import Betano
        #else
        @testable import BetanoCasinoBE
        #endif
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = TestableImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false
        )

        // When
        let imports = try await sut.testableImports(inFile: filePath)

        // Then
        #expect(imports == ["Stoiximan", "Betano", "BetanoCasinoBE"])
    }
}
