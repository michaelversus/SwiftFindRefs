import Foundation
import IndexStore
import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryTestableAnalyzer Tests")
struct UnnecessaryTestableAnalyzerTests {
    @Test("analyze returns unnecessary modules when referenced definitions are public")
    func test_analyze_ReturnsUnnecessaryModulesWhenDefinitionsArePublic() async throws {
        // Given
        let appFile = "/app/AppTests.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "@testable import ModuleA\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector(
            result: .success(
                (
                    [
                        MockUnitReader(
                            isSystem: false,
                            dependencies: [],
                            mainFile: appFile,
                            moduleName: "AppTests",
                            recordName: "AppTests",
                        )
                    ],
                    [
                        appFile: [
                            OccurrenceSnapshot(
                                symbolKind: .class,
                                roles: .reference,
                                locationLine: 10,
                                locationColumn: 5,
                                symbolUSR: "c:10ModuleA3FooC",
                                symbolName: "Foo",
                                relatedSymbols: []
                            )
                        ]
                    ]
                )
            )
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze keeps testable imports for internal definitions")
    func test_analyze_KeepsTestableImportsWhenDefinitionsAreInternal() async throws {
        // Given
        let appFile = "/app/AppTests.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "@testable import ModuleA\n",
            moduleFile: "class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result.isEmpty)
    }

    @Test("analyze throws missingModuleInIndex when testable module is not indexed")
    func test_analyze_ThrowsMissingModuleInIndexWhenModuleNotIndexed() async {
        // Given
        let appFile = "/app/AppTests.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "@testable import ModuleA\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let error = await #expect(throws: RemoveError.self) {
            _ = try await sut.analyze()
        }

        // Then
        guard case .missingModuleInIndex(let file, let modules) = error else {
            Issue.record("Expected missingModuleInIndex but got \(error)")
            return
        }
        #expect(file == appFile)
        #expect(modules == ["ModuleA"])
    }

    @Test("analyze keeps first record when multiple units share the same main file")
    func test_analyze_KeepsFirstRecordWhenUnitsShareMainFile() async throws {
        // Given
        let appFile = "/app/AppTests.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "@testable import ModuleA\n",
            moduleFile: "public class Foo {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze throws failedToLoadUnits when index store has no units")
    func test_analyze_ThrowsFailedToLoadUnitsWhenNoUnits() async {
        // Given
        let fileSystem = MockFileSystem()
        let extractor = MockImportExtractor(resultsByFile: [:])
        let collector = MockIndexStoreCollector()
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let error = await #expect(throws: RemoveError.self) {
            _ = try await sut.analyze()
        }

        // Then
        guard case .failedToLoadUnits(let path) = error else {
            Issue.record("Expected failedToLoadUnits but got \(error)")
            return
        }
        #expect(path == "/index")
    }
}
