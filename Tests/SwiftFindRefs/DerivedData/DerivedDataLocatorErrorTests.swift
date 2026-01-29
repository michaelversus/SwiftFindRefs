import Testing
@testable import SwiftFindRefs

@Suite("DerivedDataLocatorError Tests")
struct DerivedDataLocatorErrorTests {
    // MARK: - Tests
    @Test("test errorDescription with missing inputs returns guidance message")
    func test_errorDescription_WithMissingInputs_returnsGuidanceMessage() throws {
        // Given
        let sut: DerivedDataLocatorError = .missingInputs

        // When
        let description = try #require(sut.errorDescription)

        // Then
        #expect(description == "❌ Either projectName or dataStorePath must be provided.")
    }

    @Test("test errorDescription with missing derived data root includes provided path")
    func test_errorDescription_WithDerivedDataRootMissing_returnsPathSpecificMessage() throws {
        // Given
        let missingPath = "/tmp/DerivedData"
        let sut: DerivedDataLocatorError = .derivedDataRootMissing(missingPath)

        // When
        let description = try #require(sut.errorDescription)

        // Then
        #expect(description == "❌ DerivedData root directory was not found at \(missingPath).")
    }

    @Test("test errorDescription with project not found echoes project name")
    func test_errorDescription_WithProjectNotFound_returnsProjectSpecificMessage() throws {
        // Given
        let projectName = "SampleProject"
        let sut: DerivedDataLocatorError = .projectNotFound(projectName)

        // When
        let description = try #require(sut.errorDescription)

        // Then
        #expect(description == "❌ No DerivedData entry matching project \(projectName) was found.")
    }
}
