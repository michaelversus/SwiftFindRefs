import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("DerivedDataPaths Tests")
struct DerivedDataPathsTests {
    // MARK: - Tests
    @Test("test indexStoreDBURL with base derived data returns nested IndexStoreDB path")
    func test_indexStoreDBURL_WithBaseDerivedData_returnsNestedIndexStoreDBPath() {
        // Given
        let derivedDataURL = URL(fileURLWithPath: "/tmp/DerivedData", isDirectory: true)
        let sut = makeSUT(derivedDataURL: derivedDataURL)
        let expectedURL = derivedDataURL
            .appendingPathComponent("Index.noindex", isDirectory: true)
            .appendingPathComponent("DataStore", isDirectory: true)
            .appendingPathComponent("IndexStoreDB", isDirectory: true)

        // When
        let result = sut.indexStoreDBURL

        // Then
        #expect(result == expectedURL)
    }

    @Test("test indexStoreDBURL with preexisting components still appends all segments")
    func test_indexStoreDBURL_WithExistingIndexSegments_returnsExtendedPath() {
        // Given
        let derivedDataURL = URL(
            fileURLWithPath: "/tmp/DerivedData/Index.noindex",
            isDirectory: true
        )
        let sut = makeSUT(derivedDataURL: derivedDataURL)
        let expectedURL = derivedDataURL
            .appendingPathComponent("Index.noindex", isDirectory: true)
            .appendingPathComponent("DataStore", isDirectory: true)
            .appendingPathComponent("IndexStoreDB", isDirectory: true)

        // When
        let result = sut.indexStoreDBURL

        // Then
        #expect(result == expectedURL)
    }

    // MARK: - Helpers
    private func makeSUT(derivedDataURL: URL) -> DerivedDataPaths {
        DerivedDataPaths(derivedDataURL: derivedDataURL, shouldAppendExtraPaths: true)
    }
}
