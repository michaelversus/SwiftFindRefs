import Foundation
import IndexStore
import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryTestableAnalyzer Tests")
struct UnnecessaryTestableAnalyzerTests {

    // MARK: - Tests

    @Test("analyze returns unnecessary testable imports when internal definitions are not referenced")
    func test_analyze_ReturnsUnnecessaryTestableImportsWhenInternalDefinitionsAreNotReferenced() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\n",
            moduleFile: "class InternalClass {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: "usr:InternalClass",
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then
        #expect(result == [testFile: ["ModuleA"]])
    }

    @Test("analyze keeps testable imports when internal definitions are referenced")
    func test_analyze_KeepsTestableImportsWhenInternalDefinitionsAreReferenced() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet instance = InternalClass()\n",
            moduleFile: "class InternalClass {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let internalClassUSR = "usr:InternalClass"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 15,
                            symbolUSR: internalClassUSR,
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: internalClassUSR,
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
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

    @Test("analyze keeps testable imports when public definitions are referenced but not required")
    func test_analyze_KeepsTestableImportsWhenPublicDefinitionsAreReferenced() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet instance = PublicClass()\n",
            moduleFile: "public class PublicClass {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let publicClassUSR = "usr:PublicClass"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 15,
                            symbolUSR: publicClassUSR,
                            symbolName: "PublicClass",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: publicClassUSR,
                            symbolName: "PublicClass",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - public class doesn't require @testable, so it should be marked as unnecessary
        #expect(result == [testFile: ["ModuleA"]])
    }

    @Test("analyze throws missingModuleInIndex when testable module is not indexed")
    func test_analyze_ThrowsMissingModuleInIndexWhenModuleNotIndexed() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import UnknownModule\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["UnknownModule"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit],
                [testFile: []]
            ))
        )
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
        switch error {
        case .missingModuleInIndex(let file, let modules):
            #expect(file == testFile)
            #expect(modules == ["UnknownModule"])
        default:
            Issue.record("Expected missingModuleInIndex(\(testFile), [\"UnknownModule\"]), got \(error)")
        }
    }

    @Test("analyze keeps testable imports when internal method is referenced")
    func test_analyze_KeepsTestableImportsWhenInternalMethodIsReferenced() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet instance = InternalClass()\ninstance.internalMethod()\n",
            moduleFile: "class InternalClass {\n    func internalMethod() {}\n}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let classUSR = "usr:InternalClass"
        let methodUSR = "usr:internalMethod"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 15,
                            symbolUSR: classUSR,
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.reference],
                            locationLine: 3,
                            locationColumn: 9,
                            symbolUSR: methodUSR,
                            symbolName: "internalMethod",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: classUSR,
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.definition],
                            locationLine: 2,
                            locationColumn: 5,
                            symbolUSR: methodUSR,
                            symbolName: "internalMethod",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
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

    @Test("analyze ignores protocol members when determining if testable is needed")
    func test_analyze_IgnoresProtocolMembersWhenDeterminingIfTestableIsNeeded() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet instance: MyProtocol = ConcreteClass()\n",
            moduleFile: "protocol MyProtocol {\n    func protocolMethod()\n}\nclass ConcreteClass: MyProtocol {\n    func protocolMethod() {}\n}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let protocolMethodUSR = "usr:protocolMethod"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 30,
                            symbolUSR: protocolMethodUSR,
                            symbolName: "protocolMethod",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.definition],
                            locationLine: 2,
                            locationColumn: 5,
                            symbolUSR: protocolMethodUSR,
                            symbolName: "protocolMethod",
                            relatedSymbols: [
                                RelatedSymbolSnapshot(kind: .protocol, roles: [.childOf])
                            ]
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - protocol methods don't require @testable, so it should be marked as unnecessary
        // (unless ConcreteClass itself requires it, but in this case it's not referenced)
        #expect(result == [testFile: ["ModuleA"]])
    }

    @Test("analyze ignores getter and setter accessors when determining if testable is needed")
    func test_analyze_IgnoresGetterAndSetterAccessors() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet instance = InternalClass()\nlet value = instance.property\n",
            moduleFile: "class InternalClass {\n    var property: Int { get { 0 } set {} }\n}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let classUSR = "usr:InternalClass"
        let propertyUSR = "usr:property"
        let getterUSR = "usr:property.getter"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 15,
                            symbolUSR: classUSR,
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceProperty,
                            roles: [.reference],
                            locationLine: 3,
                            locationColumn: 20,
                            symbolUSR: propertyUSR,
                            symbolName: "property",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: classUSR,
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceProperty,
                            roles: [.definition],
                            locationLine: 2,
                            locationColumn: 5,
                            symbolUSR: propertyUSR,
                            symbolName: "property",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.definition, .accessorOf],
                            locationLine: 2,
                            locationColumn: 20,
                            symbolUSR: getterUSR,
                            symbolName: "get",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - property accessors don't require @testable, but the property itself does if it's internal
        // Since InternalClass is referenced, @testable is needed
        #expect(result.isEmpty)
    }

    @Test("analyze keeps testable imports when override method is referenced")
    func test_analyze_KeepsTestableImportsWhenOverrideMethodIsReferenced() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet instance = SubClass()\ninstance.publicMethod()\n",
            moduleFile: "public class BaseClass {\n    public func publicMethod() {}\n}\nclass SubClass: BaseClass {\n    override func publicMethod() {}\n}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let subclassUSR = "usr:SubClass"
        let overrideMethodUSR = "usr:publicMethod.override"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 15,
                            symbolUSR: subclassUSR,
                            symbolName: "SubClass",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.reference],
                            locationLine: 3,
                            locationColumn: 9,
                            symbolUSR: overrideMethodUSR,
                            symbolName: "publicMethod",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 4,
                            locationColumn: 1,
                            symbolUSR: subclassUSR,
                            symbolName: "SubClass",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .instanceMethod,
                            roles: [.definition, .overrideOf],
                            locationLine: 5,
                            locationColumn: 5,
                            symbolUSR: overrideMethodUSR,
                            symbolName: "publicMethod",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - override methods don't require @testable even if they're internal
        // But SubClass itself is internal and referenced, so @testable is needed
        #expect(result.isEmpty)
    }

    @Test("analyze filters out generated files")
    func test_analyze_FiltersOutGeneratedFiles() async throws {
        // Given
        let generatedFile = "/File.generated.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            generatedFile: "@testable import ModuleA\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            generatedFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: generatedFile,
            moduleName: "TestModule"
        )
        // Add ModuleA unit so it doesn't throw missing module error
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: "/modules/ModuleA.swift",
            moduleName: "ModuleA"
        )
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    generatedFile: [],
                    "/modules/ModuleA.swift": []
                ]
            ))
        )
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

    @Test("analyze filters out third-party files")
    func test_analyze_FiltersOutThirdPartyFiles() async throws {
        // Given
        let thirdPartyFile = "/Library/Developer/Xcode/SomeLibrary/File.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            thirdPartyFile: "@testable import ModuleA\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            thirdPartyFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: thirdPartyFile,
            moduleName: "TestModule"
        )
        // Add ModuleA unit so it doesn't throw missing module error
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: "/modules/ModuleA.swift",
            moduleName: "ModuleA"
        )
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    thirdPartyFile: [],
                    "/modules/ModuleA.swift": []
                ]
            ))
        )
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

    @Test("analyze handles multiple testable imports correctly")
    func test_analyze_HandlesMultipleTestableImportsCorrectly() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleAFile = "/modules/ModuleA.swift"
        let moduleBFile = "/modules/ModuleB.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\n@testable import ModuleB\n",
            moduleAFile: "class InternalClassA {}\n",
            moduleBFile: "class InternalClassB {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA", "ModuleB"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleAUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleAFile,
            moduleName: "ModuleA"
        )
        let moduleBUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleBFile,
            moduleName: "ModuleB"
        )
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleAUnit, moduleBUnit],
                [
                    testFile: [],
                    moduleAFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: "usr:InternalClassA",
                            symbolName: "InternalClassA",
                            relatedSymbols: []
                        )
                    ],
                    moduleBFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: "usr:InternalClassB",
                            symbolName: "InternalClassB",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - both modules are unnecessary since nothing is referenced
        #expect(result == [testFile: ["ModuleA", "ModuleB"]])
    }

    @Test("analyze keeps one testable import when only one module is referenced")
    func test_analyze_KeepsOneTestableImportWhenOnlyOneModuleIsReferenced() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleAFile = "/modules/ModuleA.swift"
        let moduleBFile = "/modules/ModuleB.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\n@testable import ModuleB\nlet instance = InternalClassA()\n",
            moduleAFile: "class InternalClassA {}\n",
            moduleBFile: "class InternalClassB {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA", "ModuleB"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleAUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleAFile,
            moduleName: "ModuleA"
        )
        let moduleBUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleBFile,
            moduleName: "ModuleB"
        )
        let classAUSR = "usr:InternalClassA"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleAUnit, moduleBUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.reference],
                            locationLine: 3,
                            locationColumn: 15,
                            symbolUSR: classAUSR,
                            symbolName: "InternalClassA",
                            relatedSymbols: []
                        )
                    ],
                    moduleAFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: classAUSR,
                            symbolName: "InternalClassA",
                            relatedSymbols: []
                        )
                    ],
                    moduleBFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: "usr:InternalClassB",
                            symbolName: "InternalClassB",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - ModuleA is needed, ModuleB is unnecessary
        #expect(result == [testFile: ["ModuleB"]])
    }

    @Test("analyze handles enum constants correctly")
    func test_analyze_HandlesEnumConstantsCorrectly() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\nlet value = MyEnum.case1\n",
            moduleFile: "public enum MyEnum {\n    case case1\n}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let enumUSR = "usr:MyEnum"
        let caseUSR = "usr:case1"
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [
                        OccurrenceSnapshot(
                            symbolKind: .enum,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 15,
                            symbolUSR: enumUSR,
                            symbolName: "MyEnum",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .enumConstant,
                            roles: [.reference],
                            locationLine: 2,
                            locationColumn: 23,
                            symbolUSR: caseUSR,
                            symbolName: "case1",
                            relatedSymbols: []
                        )
                    ],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .enum,
                            roles: [.definition],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: enumUSR,
                            symbolName: "MyEnum",
                            relatedSymbols: []
                        ),
                        OccurrenceSnapshot(
                            symbolKind: .enumConstant,
                            roles: [.definition],
                            locationLine: 2,
                            locationColumn: 5,
                            symbolUSR: caseUSR,
                            symbolName: "case1",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - enum constants are always considered public, and the enum itself is public,
        // so @testable is not required
        #expect(result == [testFile: ["ModuleA"]])
    }

    @Test("analyze handles implicit symbols correctly")
    func test_analyze_HandlesImplicitSymbolsCorrectly() async throws {
        // Given
        let testFile = "/test/TestFile.swift"
        let moduleFile = "/modules/ModuleA.swift"
        let fileSystem = MockFileSystem(readFileResults: [
            testFile: "@testable import ModuleA\n",
            moduleFile: "class InternalClass {}\n"
        ])
        let extractor = MockImportExtractor(resultsByFile: [
            testFile: ["ModuleA"]
        ])
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: testFile,
            moduleName: "TestModule"
        )
        let moduleUnit = MockUnitReader(
            isSystem: false,
            mainFile: moduleFile,
            moduleName: "ModuleA"
        )
        let collector = MockIndexStoreCollector(
            result: .success((
                [unit, moduleUnit],
                [
                    testFile: [],
                    moduleFile: [
                        OccurrenceSnapshot(
                            symbolKind: .class,
                            roles: [.definition, .implicit],
                            locationLine: 1,
                            locationColumn: 1,
                            symbolUSR: "usr:InternalClass",
                            symbolName: "InternalClass",
                            relatedSymbols: []
                        )
                    ]
                ]
            ))
        )
        let sut = UnnecessaryTestableAnalyzer(
            fileSystem: fileSystem,
            extractor: extractor,
            collector: collector
        )

        // When
        let result = try await sut.analyze()

        // Then - implicit symbols (except accessors) are not considered public
        #expect(result == [testFile: ["ModuleA"]])
    }
}
