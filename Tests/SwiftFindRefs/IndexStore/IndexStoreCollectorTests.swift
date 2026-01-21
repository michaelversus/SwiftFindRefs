import IndexStore
import Testing
@testable import SwiftFindRefs

@Suite("IndexStoreCollector Tests")
struct IndexStoreCollectorTests {

    // MARK: - Tests

    @Test("collectUnitsAndRecords throws failedToLoadUnits when store yields no usable units")
    func test_collectUnitsAndRecords_WhenStoreHasNoUnits_throwsFailedToLoadUnits() {
        // Given
        let store = MockIndexStore(units: [], recordReaders: [:])
        let indexStorePath = "/mock/index/store"
        let collector = IndexStoreCollector(store: store, indexStorePath: indexStorePath)

        // When
        let error = #expect(throws: RemoveError.self) {
            _ = try collector.collectUnitsAndRecords()
        }

        // Then
        switch error {
        case .failedToLoadUnits(let path):
            #expect(path == indexStorePath)
        default:
            Issue.record("Expected failedToLoadUnits(\(indexStorePath)), got \(error)")
        }
    }

    @Test("collectUnitsAndRecords skips units with empty mainFile and throws failedToLoadUnits")
    func test_collectUnitsAndRecords_WhenUnitMainFileIsEmpty_throwsFailedToLoadUnits() {
        // Given
        let store = MockIndexStore(
            units: [
                MockUnitReader(isSystem: false, mainFile: "", moduleName: "App", recordName: "Record")
            ],
            recordReaders: [
                "Record": MockRecordReader(occurrences: [])
            ]
        )
        let indexStorePath = "/mock"
        let collector = IndexStoreCollector(store: store, indexStorePath: indexStorePath)

        // When
        let error = #expect(throws: RemoveError.self) {
            _ = try collector.collectUnitsAndRecords()
        }

        // Then
        switch error {
        case .failedToLoadUnits(let path):
            #expect(path == indexStorePath)
        default:
            Issue.record("Expected failedToLoadUnits(\(indexStorePath)), got \(error)")
        }
    }

    @Test("collectUnitsAndRecords returns units and groups occurrence snapshots by main file")
    func test_collectUnitsAndRecords_WhenRecordReaderExists_returnsOccurrencesGroupedByMainFile() throws {
        // Given
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: "/mock/main.swift",
            moduleName: "App",
            recordName: "RecordA"
        )

        let occurrences = [
            MockSymbolOccurrence(
                symbolName: "MyType",
                symbolKind: .struct,
                roles: [.definition],
                locationLine: 10,
                locationColumn: 3,
                symbolUSR: "usr:MyType",
                relatedSymbols: [(MockRelatedSymbol(kind: .protocol), [.reference])]
            ),
            MockSymbolOccurrence(
                symbolName: "myFunction",
                symbolKind: .function,
                roles: [.reference],
                locationLine: 20,
                locationColumn: 1,
                symbolUSR: "usr:myFunction",
                relatedSymbols: []
            )
        ]
        let store = MockIndexStore(
            units: [unit],
            recordReaders: [
                "RecordA": MockRecordReader(occurrences: occurrences)
            ]
        )
        let collector = IndexStoreCollector(store: store, indexStorePath: "/mock")

        // When
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()

        // Then
        #expect(units.count == 1)
        #expect(units.first?.mainFile == unit.mainFile)

        let snapshots = occurrencesByFile[unit.mainFile] ?? []
        #expect(snapshots.count == 2)

        #expect(snapshots.first?.symbolName == "MyType")
        #expect(snapshots.first?.symbolKind == .struct)
        #expect(snapshots.first?.roles.contains(.definition) == true)
        #expect(snapshots.first?.locationLine == 10)
        #expect(snapshots.first?.locationColumn == 3)
        #expect(snapshots.first?.symbolUSR == "usr:MyType")
        #expect(snapshots.first?.relatedSymbols.count == 1)
        #expect(snapshots.first?.relatedSymbols.first?.kind == .protocol)
        #expect(snapshots.first?.relatedSymbols.first?.roles.contains(.reference) == true)

        #expect(snapshots.last?.symbolName == "myFunction")
        #expect(snapshots.last?.symbolKind == .function)
        #expect(snapshots.last?.locationLine == 20)
        #expect(snapshots.last?.locationColumn == 1)
        #expect(snapshots.last?.symbolUSR == "usr:myFunction")
    }

    @Test("collectUnitsAndRecords keeps first record when multiple units share the same main file")
    func test_collectUnitsAndRecords_WhenDuplicateMainFile_keepsFirstRecordOccurrences() throws {
        // Given
        let mainFile = "/mock/duplicate.swift"
        let firstUnit = MockUnitReader(
            isSystem: false,
            mainFile: mainFile,
            moduleName: "App",
            recordName: "RecordFirst"
        )
        let secondUnit = MockUnitReader(
            isSystem: false,
            mainFile: mainFile,
            moduleName: "App",
            recordName: "RecordSecond"
        )
        let firstOccurrences = [
            MockSymbolOccurrence(symbolName: "First", symbolKind: .class, locationLine: 1, locationColumn: 1, symbolUSR: "usr:first")
        ]
        let secondOccurrences = [
            MockSymbolOccurrence(symbolName: "Second", symbolKind: .class, locationLine: 2, locationColumn: 1, symbolUSR: "usr:second")
        ]
        let store = MockIndexStore(
            units: [firstUnit, secondUnit],
            recordReaders: [
                "RecordFirst": MockRecordReader(occurrences: firstOccurrences),
                "RecordSecond": MockRecordReader(occurrences: secondOccurrences)
            ]
        )
        let collector = IndexStoreCollector(store: store, indexStorePath: "/mock")

        // When
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()

        // Then
        #expect(units.count == 2)

        let snapshots = occurrencesByFile[mainFile] ?? []
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.symbolName == "First")
        #expect(snapshots.first?.locationLine == 1)
    }

    @Test("collectUnitsAndRecords ignores record reader failures and leaves occurrences empty for that file")
    func test_collectUnitsAndRecords_WhenRecordReaderThrows_doesNotAddOccurrencesForFile() throws {
        // Given
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: "/mock/file.swift",
            moduleName: "App",
            recordName: "Record"
        )
        let store = MockIndexStore(
            units: [unit],
            recordReaders: [:],
            recordReaderError: TestError.sample
        )
        let collector = IndexStoreCollector(store: store, indexStorePath: "/mock")

        // When
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()

        // Then
        #expect(units.count == 1)
        #expect(occurrencesByFile.isEmpty)
    }

    @Test("collectUnitsAndRecords does not add occurrences when unit recordName is nil")
    func test_collectUnitsAndRecords_WhenRecordNameIsNil_doesNotAddOccurrences() throws {
        // Given
        let unit = MockUnitReader(
            isSystem: false,
            mainFile: "/mock/file.swift",
            moduleName: "App",
            recordName: nil
        )
        let store = MockIndexStore(
            units: [unit],
            recordReaders: [
                "Record": MockRecordReader(occurrences: [MockSymbolOccurrence(symbolName: "ShouldNotBeUsed")])
            ]
        )
        let collector = IndexStoreCollector(store: store, indexStorePath: "/mock")

        // When
        let (units, occurrencesByFile) = try collector.collectUnitsAndRecords()

        // Then
        #expect(units.count == 1)
        #expect(occurrencesByFile.isEmpty)
    }
}
