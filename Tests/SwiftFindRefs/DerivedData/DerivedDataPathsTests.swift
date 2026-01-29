import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("DerivedDataPaths Tests")
struct DerivedDataPathsTests {
    // MARK: - Tests
    @Test("test dataStoreURL with base derived data returns nested DataStore path")
    func test_dataStoreURL_WithBaseDerivedData_returnsNestedDataStorePath() {
        // Given
        let derivedDataURL = URL(fileURLWithPath: "/tmp/DerivedData", isDirectory: true)
        let sut = makeSUT(derivedDataURL: derivedDataURL)
        let expectedURL = derivedDataURL
            .appendingPathComponent("Index.noindex", isDirectory: true)
            .appendingPathComponent("DataStore", isDirectory: true)

        // When
        let result = sut.dataStoreURL

        // Then
        #expect(result == expectedURL)
    }

    @Test("test dataStoreURL with preexisting components still appends all segments")
    func test_dataStoreURL_WithExistingIndexSegments_returnsExtendedPath() {
        // Given
        let derivedDataURL = URL(
            fileURLWithPath: "/tmp/DerivedData/Index.noindex",
            isDirectory: true
        )
        let sut = makeSUT(derivedDataURL: derivedDataURL)
        let expectedURL = derivedDataURL
            .appendingPathComponent("Index.noindex", isDirectory: true)
            .appendingPathComponent("DataStore", isDirectory: true)

        // When
        let result = sut.dataStoreURL

        // Then
        #expect(result == expectedURL)
    }

    // MARK: - Helpers
    private func makeSUT(derivedDataURL: URL) -> DerivedDataPaths {
        DerivedDataPaths(derivedDataURL: derivedDataURL, shouldAppendExtraPaths: true)
    }
}
