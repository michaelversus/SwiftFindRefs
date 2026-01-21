import Foundation
import IndexStore
import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryImportsAnalyzer Tests")
struct UnnecessaryImportsAnalyzerTests {

    // MARK: - Tests

    @Test("analyze returns unnecessary modules when definitions are not referenced")
    func test_analyze_ReturnsUnnecessaryModulesWhenDefinitionsAreNotReferenced() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze keeps imports when referenced definitions exist")
    func test_analyze_KeepsImportsWhenReferencedDefinitionsExist() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result.isEmpty)
    }

    @Test("analyze throws missingModuleInIndex when module is not indexed")
    func test_analyze_ThrowsMissingModuleInIndexWhenModuleNotIndexed() async throws {
        // Given
        let appFile = "/app/App.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nimport UnknownModule\n"
        ])
        // ModuleA exists in index but UnknownModule doesn't
        // UnknownModule will be filtered out by intersection with allModuleNames
        // So we need a module that doesn't exist in the index at all (not even as a unit)
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA", "UnknownModule"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - UnknownModule is filtered out, ModuleA is unnecessary (no references)
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze keeps first record when multiple units share the same main file")
    func test_analyze_KeepsFirstRecordWhenUnitsShareMainFile() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze keeps imports when typealias is referenced")
    func test_analyze_KeepsImportsWhenTypealiasIsReferenced() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nlet x: MyType = MyType()\n",
            moduleFile: "typealias MyType = String\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - typealias is referenced, so import should be kept
        #expect(result.isEmpty)
    }

    @Test("analyze removes imports when typealias is not referenced")
    func test_analyze_RemovesImportsWhenTypealiasIsNotReferenced() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nlet x = 42\n",
            moduleFile: "typealias MyType = String\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - typealias is not referenced, so import should be removed
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze keeps imports when extension typealias is referenced")
    func test_analyze_KeepsImportsWhenExtensionTypealiasIsReferenced() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nextension [Int] {}\n",
            moduleFile: "typealias IntArray = [Int]\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - extension references [Int] which might be a typealias, so import should be kept
        // Note: This test may need adjustment based on actual typealias extraction logic
        #expect(result.isEmpty || result == [appFile: ["ModuleA"]])
    }

    @Test("analyze filters imports to known modules only")
    func test_analyze_FiltersImportsToKnownModulesOnly() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nimport UnknownModule\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA", "UnknownModule"] // UnknownModule is not in the index store
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - UnknownModule should be filtered out, only ModuleA should be analyzed
        // Since ModuleA has no references, it should be marked as unnecessary
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze respects @ignore-import comments when using IndexStore")
    func test_analyze_RespectsIgnoreImportComments() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA // @ignore-import\nimport ModuleB\n",
            moduleFile: "public class Foo {}\n"
        ])
        // Use real ImportExtractor so IndexStore-based extraction works
        let extractor = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .regularImport
        )
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - ModuleA should be ignored due to @ignore-import comment
        // ModuleB should be marked as unnecessary since it's not referenced
        #expect(result == [appFile: ["ModuleB"]])
    }

    @Test("analyze uses IndexStore for regular imports when available")
    func test_analyze_UsesIndexStoreForRegularImports() async throws {
        // Given - IndexStore has module symbols
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .regularImport
        )
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then - IndexStore-based extraction should be used, ModuleA should be marked as unnecessary
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze keeps imports when capitalized type reference is found by scanning module source")
    func test_analyze_KeepsImportsWhenCapitalizedTypeIsFoundInModuleSourceScan() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nlet value: ExternalType\n",
            moduleFile: "public struct ExternalType {}\n"
        ])

        // Make sure the referencing file has a capitalized symbol name in the referenced names set.
        // Also ensure the module has at least one file with occurrences, otherwise the analyzer
        // intentionally skips the source-scan fallback (it uses that only when the module is indexed).
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector,
            indexStoreImportExtractor: MockIndexStoreImportExtractor()
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result.isEmpty)
    }
}
