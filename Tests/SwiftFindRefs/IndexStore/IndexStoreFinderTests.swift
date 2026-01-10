import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("IndexStoreFinder Tests")
struct IndexStoreFinderTests {

    // MARK: - fileReferences

    @Test("test fileReferences with invalid path throws error")
    func test_fileReferences_WithInvalidPath_throwsError() {
        // Given
        let sut = makeSUT(indexStorePath: "/nonexistent/index/store")

        // When / Then
        #expect(throws: (any Error).self) {
            _ = try sut.fileReferences(of: "SomeSymbol", symbolType: nil)
        }
    }

    // MARK: - Helpers

    private func makeSUT(indexStorePath: String) -> IndexStoreFinder {
        IndexStoreFinder(indexStorePath: indexStorePath)
    }
}
