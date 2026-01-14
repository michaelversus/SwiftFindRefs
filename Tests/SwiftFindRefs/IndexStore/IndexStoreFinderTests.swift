import Foundation
import Testing
import IndexStore
@testable import SwiftFindRefs

@Suite("IndexStoreFinder Tests")
struct IndexStoreFinderTests {

    // MARK: - fileReferences with invalid path

    @Test("test fileReferences with invalid path throws error")
    func test_fileReferences_WithInvalidPath_throwsError() {
        // Given
        let sut = makeSUT(indexStorePath: "/nonexistent/index/store")

        // When / Then
        #expect(throws: (any Error).self) {
            _ = try sut.fileReferences(of: "SomeSymbol", symbolType: nil)
        }
    }

    // MARK: - fileReferences with mock store

    @Test("test fileReferences with empty store returns empty array")
    func test_fileReferences_WithEmptyStore_returnsEmptyArray() throws {
        // Given
        let sut = makeSUT()
        let store = MockIndexStore(units: [], recordReaders: [:])

        // When
        let result = try sut.fileReferences(of: "SomeSymbol", symbolType: nil, from: store)

        // Then
        #expect(result.isEmpty)
    }

    @Test("test fileReferences with matching symbol returns file path")
    func test_fileReferences_WithMatchingSymbol_returnsFilePath() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "MyClass"
        let filePath = "/path/to/MyClass.swift"
        let recordName = "MyClassRecord"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: recordName, filePath: filePath)
                    ]
                )
            ],
            recordReaders: [
                recordName: MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .class))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: nil, from: store)

        // Then
        #expect(result.count == 1)
        #expect(result.contains(filePath))
    }

    @Test("test fileReferences with non-matching symbol returns empty array")
    func test_fileReferences_WithNonMatchingSymbol_returnsEmptyArray() throws {
        // Given
        let sut = makeSUT()
        let recordName = "SomeRecord"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: recordName, filePath: "/path/to/file.swift")
                    ]
                )
            ],
            recordReaders: [
                recordName: MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: "DifferentSymbol", kind: .class))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: "MySymbol", symbolType: nil, from: store)

        // Then
        #expect(result.isEmpty)
    }

    @Test("test fileReferences with matching name but different kind returns empty array")
    func test_fileReferences_WithMatchingNameButDifferentKind_returnsEmptyArray() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "Selection"
        let recordName = "SelectionRecord"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: recordName, filePath: "/path/to/file.swift")
                    ]
                )
            ],
            recordReaders: [
                recordName: MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .struct))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: "class", from: store)

        // Then
        #expect(result.isEmpty)
    }

    @Test("test fileReferences with nil symbol type matches any kind")
    func test_fileReferences_WithNilSymbolType_matchesAnyKind() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "MySymbol"
        let recordName = "MyRecord"
        let filePath = "/path/to/file.swift"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: recordName, filePath: filePath)
                    ]
                )
            ],
            recordReaders: [
                recordName: MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .function))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: nil, from: store)

        // Then
        #expect(result.count == 1)
        #expect(result.contains(filePath))
    }

    @Test("test fileReferences with multiple matching files returns sorted paths")
    func test_fileReferences_WithMultipleMatchingFiles_returnsSortedPaths() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "SharedProtocol"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: "Record1", filePath: "/z/path.swift"),
                        MockUnitDependency(kind: .record, name: "Record2", filePath: "/a/path.swift"),
                        MockUnitDependency(kind: .record, name: "Record3", filePath: "/m/path.swift")
                    ]
                )
            ],
            recordReaders: [
                "Record1": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .protocol))
                ]),
                "Record2": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .protocol))
                ]),
                "Record3": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .protocol))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: nil, from: store)

        // Then
        #expect(result.count == 3)
        #expect(result == ["/a/path.swift", "/m/path.swift", "/z/path.swift"])
    }

    @Test("test fileReferences skips system units")
    func test_fileReferences_WithSystemUnits_skipsThem() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "MyClass"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: true,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: "SystemRecord", filePath: "/system/path.swift")
                    ]
                )
            ],
            recordReaders: [
                "SystemRecord": MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .class))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: nil, from: store)

        // Then
        #expect(result.isEmpty)
    }

    @Test("test fileReferences with unreadable record skips it")
    func test_fileReferences_WithUnreadableRecord_skipsIt() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "MyClass"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: "UnreadableRecord", filePath: "/path.swift")
                    ]
                )
            ],
            recordReaders: [:] // No record reader for "UnreadableRecord"
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: nil, from: store)

        // Then
        #expect(result.isEmpty)
    }

    @Test("test fileReferences deduplicates files when symbol appears multiple times")
    func test_fileReferences_WithDuplicateRecords_deduplicatesFiles() throws {
        // Given
        let sut = makeSUT()
        let symbolName = "MyClass"
        let filePath = "/path/to/file.swift"
        let recordName = "Record1"
        
        let store = MockIndexStore(
            units: [
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: recordName, filePath: filePath)
                    ]
                ),
                MockUnitReader(
                    isSystem: false,
                    dependencies: [
                        MockUnitDependency(kind: .record, name: recordName, filePath: filePath)
                    ]
                )
            ],
            recordReaders: [
                recordName: MockRecordReader(occurrences: [
                    MockSymbolOccurrence(symbol: MockSymbol(name: symbolName, kind: .class))
                ])
            ]
        )

        // When
        let result = try sut.fileReferences(of: symbolName, symbolType: nil, from: store)

        // Then
        #expect(result.count == 1)
        #expect(result.contains(filePath))
    }

    // MARK: - Helpers

    private func makeSUT(indexStorePath: String = "/mock/path") -> IndexStoreFinder {
        IndexStoreFinder(indexStorePath: indexStorePath)
    }
}

// MARK: - Test Doubles

private struct MockSymbol: SymbolMatching {
    let name: String
    let kind: SymbolKind
}

private struct MockSymbolOccurrence: SymbolOccurrenceProviding {
    let symbol: MockSymbol
    
    var symbolMatching: SymbolMatching {
        symbol
    }
}

private struct MockRecordReader: RecordReaderProviding {
    let occurrences: [MockSymbolOccurrence]
    
    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void) {
        occurrences.forEach { callback($0) }
    }
}

private struct MockUnitDependency: UnitDependencyProviding {
    let kind: DependencyKind
    let name: String
    let filePath: String
}

private struct MockUnitReader: UnitReaderProviding {
    let isSystem: Bool
    let dependencies: [MockUnitDependency]
    
    func forEachDependency(_ callback: (UnitDependencyProviding) -> Void) {
        dependencies.forEach { callback($0) }
    }
}

private struct MockIndexStore: IndexStoreProviding {
    let units: [MockUnitReader]
    let recordReaders: [String: MockRecordReader]
    
    func forEachUnit(_ callback: (UnitReaderProviding) -> Void) {
        units.forEach { callback($0) }
    }
    
    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        recordReaders[recordName]
    }
}
