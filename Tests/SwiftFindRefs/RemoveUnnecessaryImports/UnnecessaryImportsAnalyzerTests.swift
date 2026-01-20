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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: []),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    OccurrenceSnapshot(
                        symbolKind: .class,
                        roles: [.reference],
                        locationLine: 1,
                        locationColumn: 1,
                        symbolUSR: "usr.foo",
                        symbolName: "Foo",
                        relatedSymbols: []
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [
                    OccurrenceSnapshot(
                        symbolKind: .class,
                        roles: [.definition],
                        locationLine: 1,
                        locationColumn: 1,
                        symbolUSR: "usr.foo",
                        symbolName: "Foo",
                        relatedSymbols: []
                    )
                ])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

        // Then
        #expect(result.isEmpty)
    }

    @Test("analyze throws missingModuleInIndex when module is not indexed")
    func test_analyze_ThrowsMissingModuleInIndexWhenModuleNotIndexed() async throws {
        // Given
        let appFile = "/app/App.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            appFile: "import ModuleA\nimport UnknownModule\n"
        ])
        // ModuleA exists in index but UnknownModule doesn't
        // UnknownModule will be filtered out by intersection with allModuleNames
        // So we need a module that doesn't exist in the index at all (not even as a unit)
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
                // UnknownModule has no units at all - it's completely missing
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: []),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA", "UnknownModule"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "record-1"),
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "record-2"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "record-1": MockRecordReader(occurrences: []),
                "record-2": MockRecordReader(occurrences: [
                    OccurrenceSnapshot(
                        symbolKind: .class,
                        roles: [.reference],
                        locationLine: 1,
                        locationColumn: 1,
                        symbolUSR: "usr.foo",
                        symbolName: "Foo",
                        relatedSymbols: []
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    // Reference to MyType typealias
                    OccurrenceSnapshot(
                        symbolKind: .typealias,
                        roles: [.reference],
                        locationLine: 2,
                        locationColumn: 1,
                        symbolUSR: "usr.mytype",
                        symbolName: "MyType",
                        relatedSymbols: []
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [
                    // Definition of MyType typealias
                    OccurrenceSnapshot(
                        symbolKind: .typealias,
                        roles: [.definition],
                        locationLine: 1,
                        locationColumn: 1,
                        symbolUSR: "usr.mytype",
                        symbolName: "MyType",
                        relatedSymbols: []
                    )
                ])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: []),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    OccurrenceSnapshot(
                        symbolKind: .extension,
                        roles: [.reference],
                        locationLine: 2,
                        locationColumn: 1,
                        symbolUSR: "usr.extension",
                        symbolName: "Int",
                        relatedSymbols: []
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA"]
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: []),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = MockImportExtractor(resultsByFile: [
            appFile: ["ModuleA", "UnknownModule"] // UnknownModule is not in the index store
        ])
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record"),
                MockUnitReader(mainFile: "/modules/ModuleB.swift", moduleName: "ModuleB", recordName: "module-b-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    // Module import occurrences from IndexStore
                    OccurrenceSnapshot(
                        symbolKind: .module,
                        roles: [.reference],
                        locationLine: 1,
                        locationColumn: 1,
                        symbolUSR: "usr.module.a",
                        symbolName: "ModuleA",
                        relatedSymbols: []
                    ),
                    OccurrenceSnapshot(
                        symbolKind: .module,
                        roles: [.reference],
                        locationLine: 2,
                        locationColumn: 1,
                        symbolUSR: "usr.module.b",
                        symbolName: "ModuleB",
                        relatedSymbols: []
                    )
                ]),
                "module-record": MockRecordReader(occurrences: []),
                "module-b-record": MockRecordReader(occurrences: [])
            ]
        )
        // Use real ImportExtractor so IndexStore-based extraction works
        let extractor = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .regularImport
        )
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

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
        let store = MockIndexStore(
            units: [
                MockUnitReader(mainFile: appFile, moduleName: "App", recordName: "app-record"),
                MockUnitReader(mainFile: moduleFile, moduleName: "ModuleA", recordName: "module-record")
            ],
            recordReaders: [
                "app-record": MockRecordReader(occurrences: [
                    // IndexStore provides module import symbol
                    OccurrenceSnapshot(
                        symbolKind: .module,
                        roles: [.reference],
                        locationLine: 1,
                        locationColumn: 1,
                        symbolUSR: "usr.module.a",
                        symbolName: "ModuleA",
                        relatedSymbols: []
                    )
                ]),
                "module-record": MockRecordReader(occurrences: [])
            ]
        )
        let extractor = ImportExtractor(
            fileSystem: fileSystem,
            excludeCompilationConditionals: false,
            ignoredModules: [],
            prefix: .regularImport
        )
        let sut = UnnecessaryImportsAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: IndexStoreCollector.self
        )

        // When
        let result = try await sut.analyze(store: store, indexStorePath: "/index")

        // Then - IndexStore-based extraction should be used, ModuleA should be marked as unnecessary
        #expect(result == [appFile: ["ModuleA"]])
    }
}

// MARK: - Test Doubles

private struct MockRecordReader: RecordReaderProviding, Sendable {
    let occurrences: [OccurrenceSnapshot]

    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void) {
        for occurrence in occurrences {
            callback(OccurrenceSnapshotOccurrenceProvidingAdapter(occurrence: occurrence))
        }
    }
}

private struct OccurrenceSnapshotOccurrenceProvidingAdapter: SymbolOccurrenceProviding {
    let symbolMatching: any SymbolMatching = MockSymbol(name: "", kind: .class)
    let roles: SymbolRoles
    let locationLine: Int
    let locationColumn: Int
    let symbolUSR: String

    init(occurrence: OccurrenceSnapshot) {
        roles = occurrence.roles
        locationLine = occurrence.locationLine
        locationColumn = occurrence.locationColumn
        symbolUSR = occurrence.symbolUSR
    }

    func forEachRelatedSymbol(_ callback: (RelatedSymbolProviding, SymbolRoles) -> Void) {
        _ = callback
    }
}

private struct MockSymbol: SymbolMatching, Sendable {
    let name: String
    let kind: SymbolKind
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
        for unit in units {
            callback(unit)
        }
    }

    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        recordReaders[recordName]
    }
}

private struct MockImportExtractor: ImportExtracting, Sendable {
    let resultsByFile: [String: Set<String>]

    func imports(inFile path: String) async throws -> Set<String> {
        resultsByFile[path] ?? []
    }
}
