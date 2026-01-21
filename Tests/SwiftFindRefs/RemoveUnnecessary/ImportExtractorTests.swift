import Testing
@testable import SwiftFindRefs

@Suite("ImportExtractor Tests")
struct ImportExtractorTests {
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
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .testableImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

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
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: true,
            ignoredModules: [],
            prefix: .testableImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

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
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .testableImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

        // Then
        #expect(imports == ["Stoiximan", "Betano", "BetanoCasinoBE"])
    }

    @Test("skips regular imports that have no module name")
    func test_skipsRegularImportsWithoutModuleName() async throws {
        // Given
        let filePath = "/mock/emptyImport.swift"
        let contents = """
        import    
        import ModuleA
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .regularImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

        // Then
        #expect(imports == ["ModuleA"])
    }

    @Test("skips @testable imports that have no module name")
    func test_skipsTestableImportsWithoutModuleName() async throws {
        // Given
        let filePath = "/mock/emptyTestableImport.swift"
        let contents = """
        @testable import    
        @testable import ModuleA
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .testableImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

        // Then
        #expect(imports == ["ModuleA"])
    }

    @Test("skips regular imports whose module is in ignoredModules")
    func test_skipsIgnoredRegularImports() async throws {
        // Given
        let filePath = "/mock/ignoredRegularImport.swift"
        let contents = """
        import ModuleA
        import ModuleB
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: ["ModuleA"],
            prefix: .regularImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

        // Then
        #expect(imports == ["ModuleB"])
    }

    @Test("skips @testable imports whose module is in ignoredModules")
    func test_skipsIgnoredTestableImports() async throws {
        // Given
        let filePath = "/mock/ignoredTestableImport.swift"
        let contents = """
        @testable import ModuleA
        @testable import ModuleB
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: ["ModuleA"],
            prefix: .testableImport
        )

        // When
        let imports = try await sut.imports(inFile: filePath)

        // Then
        #expect(imports == ["ModuleB"])
    }
}
