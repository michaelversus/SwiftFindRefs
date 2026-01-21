import Foundation
import Testing
import IndexStore
@testable import SwiftFindRefs

@Suite("RecordIndex Tests")
struct RecordIndexTests {
    
    // MARK: - Initialization Tests
    
    @Test("test init with empty arrays creates empty index")
    func test_init_WithEmptyArrays_createsEmptyIndex() {
        // Given / When
        let sut = makeSUT(recordNames: [], recordToSource: [:])
        
        // Then
        #expect(sut.recordNames.isEmpty)
    }
    
    @Test("test init with record names stores them")
    func test_init_WithRecordNames_storesThem() {
        // Given
        let expectedNames = ["Record1", "Record2", "Record3"]
        
        // When
        let sut = makeSUT(recordNames: expectedNames, recordToSource: [:])
        
        // Then
        #expect(sut.recordNames == expectedNames)
    }
    
    // MARK: - sourcePath Tests
    
    @Test("test sourcePath with mapped record returns source path")
    func test_sourcePath_WithMappedRecord_returnsSourcePath() {
        // Given
        let recordName = "MyRecord"
        let expectedPath = "/path/to/MyFile.swift"
        let sut = makeSUT(
            recordNames: [recordName],
            recordToSource: [recordName: expectedPath]
        )
        
        // When
        let result = sut.sourcePath(for: recordName)
        
        // Then
        #expect(result == expectedPath)
    }
    
    @Test("test sourcePath with unmapped record returns record name as fallback")
    func test_sourcePath_WithUnmappedRecord_returnsRecordNameAsFallback() {
        // Given
        let recordName = "UnmappedRecord"
        let sut = makeSUT(
            recordNames: [recordName],
            recordToSource: [:]
        )
        
        // When
        let result = sut.sourcePath(for: recordName)
        
        // Then
        #expect(result == recordName)
    }
    
    @Test("test sourcePath with multiple records returns correct paths")
    func test_sourcePath_WithMultipleRecords_returnsCorrectPaths() {
        // Given
        let record1 = "Record1"
        let record2 = "Record2"
        let record3 = "Record3"
        let path1 = "/path/to/File1.swift"
        let path2 = "/path/to/File2.swift"
        let sut = makeSUT(
            recordNames: [record1, record2, record3],
            recordToSource: [
                record1: path1,
                record2: path2
                // record3 intentionally unmapped
            ]
        )
        
        // When / Then
        #expect(sut.sourcePath(for: record1) == path1)
        #expect(sut.sourcePath(for: record2) == path2)
        #expect(sut.sourcePath(for: record3) == record3) // fallback to record name
    }
    
    @Test("test sourcePath with nonexistent record returns the record name")
    func test_sourcePath_WithNonexistentRecord_returnsRecordName() {
        // Given
        let sut = makeSUT(
            recordNames: ["ExistingRecord"],
            recordToSource: ["ExistingRecord": "/path/to/file.swift"]
        )
        let nonexistentRecord = "NonexistentRecord"
        
        // When
        let result = sut.sourcePath(for: nonexistentRecord)
        
        // Then
        #expect(result == nonexistentRecord)
    }
    
    // MARK: - build Tests
    
    @Test("test build with empty store returns empty index")
    func test_build_WithEmptyStore_returnsEmptyIndex() {
        // Given
        let store = MockIndexStore(units: [])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.recordNames.isEmpty)
    }
    
    @Test("test build with system units skips them")
    func test_build_WithSystemUnits_skipsThem() {
        // Given
        let systemUnit = MockUnitReader(
            isSystem: true,
            dependencies: [
                MockUnitDependency(kind: .record, name: "SystemRecord", filePath: "/system/path.swift")
            ]
        )
        let store = MockIndexStore(units: [systemUnit])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.recordNames.isEmpty)
    }
    
    @Test("test build with non-system unit collects record dependencies")
    func test_build_WithNonSystemUnit_collectsRecordDependencies() {
        // Given
        let expectedRecordName = "MyRecord"
        let expectedFilePath = "/path/to/MyFile.swift"
        let unit = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .record, name: expectedRecordName, filePath: expectedFilePath)
            ]
        )
        let store = MockIndexStore(units: [unit])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.recordNames.contains(expectedRecordName))
        #expect(sut.sourcePath(for: expectedRecordName) == expectedFilePath)
    }
    
    @Test("test build ignores non-record dependencies")
    func test_build_WithNonRecordDependencies_ignoresThem() {
        // Given
        let unit = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .unit, name: "UnitDep", filePath: "/unit/path.swift"),
                MockUnitDependency(kind: .file, name: "FileDep", filePath: "/file/path.swift"),
                MockUnitDependency(kind: .record, name: "RecordDep", filePath: "/record/path.swift")
            ]
        )
        let store = MockIndexStore(units: [unit])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.recordNames.count == 1)
        #expect(sut.recordNames.contains("RecordDep"))
    }
    
    @Test("test build with empty file path uses record name as fallback")
    func test_build_WithEmptyFilePath_usesRecordNameAsFallback() {
        // Given
        let recordName = "RecordWithEmptyPath"
        let unit = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .record, name: recordName, filePath: "")
            ]
        )
        let store = MockIndexStore(units: [unit])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.recordNames.contains(recordName))
        #expect(sut.sourcePath(for: recordName) == recordName)
    }
    
    @Test("test build with duplicate records keeps first file path")
    func test_build_WithDuplicateRecords_keepsFirstFilePath() {
        // Given
        let recordName = "DuplicateRecord"
        let firstPath = "/first/path.swift"
        let secondPath = "/second/path.swift"
        let unit1 = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .record, name: recordName, filePath: firstPath)
            ]
        )
        let unit2 = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .record, name: recordName, filePath: secondPath)
            ]
        )
        let store = MockIndexStore(units: [unit1, unit2])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.sourcePath(for: recordName) == firstPath)
    }
    
    @Test("test build with multiple units collects all records")
    func test_build_WithMultipleUnits_collectsAllRecords() {
        // Given
        let unit1 = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .record, name: "Record1", filePath: "/path1.swift")
            ]
        )
        let unit2 = MockUnitReader(
            isSystem: false,
            dependencies: [
                MockUnitDependency(kind: .record, name: "Record2", filePath: "/path2.swift")
            ]
        )
        let systemUnit = MockUnitReader(
            isSystem: true,
            dependencies: [
                MockUnitDependency(kind: .record, name: "SystemRecord", filePath: "/system.swift")
            ]
        )
        let store = MockIndexStore(units: [unit1, systemUnit, unit2])
        
        // When
        let sut = RecordIndex.build(from: store)
        
        // Then
        #expect(sut.recordNames.count == 2)
        #expect(sut.recordNames.contains("Record1"))
        #expect(sut.recordNames.contains("Record2"))
        #expect(!sut.recordNames.contains("SystemRecord"))
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        recordNames: [String],
        recordToSource: [String: String]
    ) -> RecordIndex {
        RecordIndex(recordNames: recordNames, recordToSource: recordToSource)
    }
}
