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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(
                        symbol: MockSymbol(name: "Foo", kind: .class),
                        roles: [.reference],
                        locationLine: 1,
                        symbolUSR: "usr.foo"
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(
                        symbol: MockSymbol(name: "Foo", kind: .class),
                        roles: [.definition],
                        locationLine: 1,
                        symbolUSR: "usr.foo"
                    )
                ])
            ]
        )
        let extractor = MockTestableImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(
                        symbol: MockSymbol(name: "Foo", kind: .class),
                        roles: [.reference],
                        locationLine: 1,
                        symbolUSR: "usr.foo"
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(
                        symbol: MockSymbol(name: "Foo", kind: .class),
                        roles: [.definition],
                        locationLine: 1,
                        symbolUSR: "usr.foo"
                    )
                ])
            ]
        )
        let extractor = MockTestableImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockTestableImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor
        )

        // When
        let error = await #expect(throws: UnnecessaryTestableError.self) {
            _ = try await sut.analyze(store: store, indexStorePath: "/index")
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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "record-1"),
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "record-2"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "record-1": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(
                        symbol: MockSymbol(name: "Foo", kind: .class),
                        roles: [.reference],
                        locationLine: 1,
                        symbolUSR: "usr.foo"
                    )
                ]),
                "record-2": MockRecordReader(occurrences: []),
                "module-record": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(
                        symbol: MockSymbol(name: "Foo", kind: .class),
                        roles: [.definition],
                        locationLine: 1,
                        symbolUSR: "usr.foo"
                    )
                ])
            ]
        )
        let extractor = MockTestableImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

        // Then
        #expect(result == [appFile: ["ModuleA"]])
    }

    @Test("analyze throws failedToLoadUnits when index store has no units")
    func test_analyze_ThrowsFailedToLoadUnitsWhenNoUnits() async {
        // Given
        let fileSystem = MockFileSystem()
        let store = MockIndexStore(units: [], recordReaders: [:])
        let extractor = MockTestableImportExtractor(resultsByFile: [:])
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor
        )

        // When
        let error = await #expect(throws: UnnecessaryTestableError.self) {
            _ = try await sut.analyze(store: store, indexStorePath: "/index")
        }

        // Then
        guard case .failedToLoadUnits(let path) = error else {
            Issue.record("Expected failedToLoadUnits but got \(error)")
            return
        }
        #expect(path == "/index")
    }
}

// MARK: - Test Doubles

private struct MockSymbol: SymbolMatching, Sendable {
    let name: String
    let kind: SymbolKind
}

private struct MockRelatedSymbol: RelatedSymbolProviding, Sendable {
    let kind: SymbolKind
}

private struct MockSymbolOccurrence: SymbolOccurrenceProviding, Sendable {
    let symbol: MockSymbol
    let roles: SymbolRoles
    let locationLine: Int
    let symbolUSR: String
    let relatedSymbols: [(MockRelatedSymbol, SymbolRoles)]

    init(
        symbol: MockSymbol,
        roles: SymbolRoles = [],
        locationLine: Int = 1,
        symbolUSR: String = "mock.usr",
        relatedSymbols: [(MockRelatedSymbol, SymbolRoles)] = []
    ) {
        self.symbol = symbol
        self.roles = roles
        self.locationLine = locationLine
        self.symbolUSR = symbolUSR
        self.relatedSymbols = relatedSymbols
    }

    var symbolMatching: SymbolMatching {
        symbol
    }

    func forEachRelatedSymbol(_ callback: (RelatedSymbolProviding, SymbolRoles) -> Void) {
        relatedSymbols.forEach { callback($0.0, $0.1) }
    }
}

private struct MockRecordReader: RecordReaderProviding, Sendable {
    let occurrences: [MockSymbolOccurrence]

    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void) {
        occurrences.forEach { callback($0) }
    }
}

private struct MockUnitReader: UnitReaderProviding, Sendable {
    let isSystem: Bool
    let mainFile: String
    let moduleName: String
    let recordName: String?

    init(
        isSystem: Bool = false,
        mainFile: String,
        moduleName: String,
        recordName: String?
    ) {
        self.isSystem = isSystem
        self.mainFile = mainFile
        self.moduleName = moduleName
        self.recordName = recordName
    }

    func forEachDependency(_ callback: (UnitDependencyProviding) -> Void) {
        _ = callback
    }
}

private struct MockIndexStore: IndexStoreProviding, Sendable {
    let units: [MockUnitReader]
    let recordReaders: [String: MockRecordReader]

    func forEachUnit(_ callback: (UnitReaderProviding) -> Void) {
        units.forEach { callback($0) }
    }

    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        recordReaders[recordName]
    }
}

private struct MockTestableImportExtractor: TestableImportExtracting, Sendable {
    let resultsByFile: [String: Set<String>]

    func testableImports(inFile path: String) async throws -> Set<String> {
        resultsByFile[path] ?? []
    }
}
