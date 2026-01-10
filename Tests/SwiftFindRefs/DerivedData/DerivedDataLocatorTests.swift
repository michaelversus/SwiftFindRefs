import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("DerivedDataLocator Tests")
struct DerivedDataLocatorTests {
    // MARK: - Tests
    @Test("test locateDerivedData with direct path exists returns provided URL")
    func test_locateDerivedData_WithDirectPathExists_returnsProvidedURL() throws {
        // Given
        let providedPath = "/tmp/ManualDerivedData-\(UUID().uuidString)"
        let fileSystem = MockFileSystem(
            fileExistsResults: [providedPath: true]
        )
        let sut = makeSUT(fileSystem: fileSystem)

        // When
        let result = try sut.locateDerivedData(projectName: nil, derivedDataPath: providedPath)

        // Then
        let expectedURL = URL(fileURLWithPath: providedPath).standardizedFileURL
        #expect(result.derivedDataURL == expectedURL)
    }

    @Test("test locateDerivedData with direct path missing throws invalidPath")
    func test_locateDerivedData_WithDirectPathMissing_throwsInvalidPath() {
        // Given
        let providedPath = "/tmp/MissingDerivedData-\(UUID().uuidString)"
        let fileSystem = MockFileSystem()
        let sut = makeSUT(fileSystem: fileSystem)

        // When
        let error = #expect(throws: DerivedDataLocatorError.self) {
            try sut.locateDerivedData(projectName: nil, derivedDataPath: providedPath)
        }

        // Then
        switch error {
        case .invalidPath(let path):
            let expectedPath = URL(fileURLWithPath: providedPath).standardizedFileURL.path
            #expect(path == expectedPath)
        default:
            Issue.record("Expected invalidPath error, received \(error)")
        }
    }

    @Test("test locateDerivedData without project and derived path throws missingInputs")
    func test_locateDerivedData_WithoutInputs_throwsMissingInputs() {
        // Given
        let sut = makeSUT()

        // When
        let error = #expect(throws: DerivedDataLocatorError.self) {
            try sut.locateDerivedData(projectName: nil, derivedDataPath: nil)
        }

        // Then
        switch error {
        case .missingInputs:
            break
        default:
            Issue.record("Expected missingInputs error, received \(error)")
        }
    }

    @Test("test locateDerivedData with missing derived data root throws derivedDataRootMissing")
    func test_locateDerivedData_WithMissingRoot_throwsDerivedDataRootMissing() {
        // Given
        let libraryURL = URL(fileURLWithPath: "/tmp/Library-\(UUID().uuidString)", isDirectory: true)
        let fileSystem = MockFileSystem(libraryDirectoryURL: libraryURL)
        let sut = makeSUT(fileSystem: fileSystem)
        let expectedRootPath = derivedDataRootURL(for: libraryURL).path

        // When
        let error = #expect(throws: DerivedDataLocatorError.self) {
            try sut.locateDerivedData(projectName: "SampleProject", derivedDataPath: nil)
        }

        // Then
        switch error {
        case .derivedDataRootMissing(let path):
            #expect(path == expectedRootPath)
        default:
            Issue.record("Expected derivedDataRootMissing error, received \(error)")
        }
    }

    @Test("test locateDerivedData with no matching entries throws projectNotFound")
    func test_locateDerivedData_WithNoMatchingEntries_throwsProjectNotFound() {
        // Given
        let libraryURL = URL(fileURLWithPath: "/tmp/Library-\(UUID().uuidString)", isDirectory: true)
        let derivedDataRoot = derivedDataRootURL(for: libraryURL)
        let fileSystem = MockFileSystem(
            fileExistsResults: [derivedDataRoot.path: true],
            libraryDirectoryURL: libraryURL,
            contentsOfDirectoryResults: [
                derivedDataRoot: [
                    derivedDataRoot.appendingPathComponent("DifferentProject-ABC", isDirectory: true)
                ]
            ]
        )
        let sut = makeSUT(fileSystem: fileSystem)

        // When
        let error = #expect(throws: DerivedDataLocatorError.self) {
            try sut.locateDerivedData(projectName: "TargetProject", derivedDataPath: nil)
        }

        // Then
        switch error {
        case .projectNotFound(let name):
            #expect(name == "TargetProject")
        default:
            Issue.record("Expected projectNotFound error, received \(error)")
        }
    }

    @Test("test locateDerivedData selects newest matching derived data directory")
    func test_locateDerivedData_WithMultipleCandidates_returnsNewestMatch() throws {
        // Given
        let projectName = "SwiftFindRefs"
        let hierarchy = try prepareDerivedDataHierarchy(projectName: projectName)
        defer { try? FileManager.default.removeItem(at: hierarchy.cleanupURL) }
        let fileSystem = MockFileSystem(
            fileExistsResults: [hierarchy.derivedDataRoot.path: true],
            libraryDirectoryURL: hierarchy.libraryURL,
            contentsOfDirectoryResults: [
                hierarchy.derivedDataRoot: [
                    hierarchy.olderURL,
                    hierarchy.unrelatedURL,
                    hierarchy.newestURL
                ]
            ]
        )
        let sut = makeSUT(fileSystem: fileSystem)

        // When
        let result = try sut.locateDerivedData(projectName: projectName, derivedDataPath: nil)

        // Then
        #expect(result.derivedDataURL == hierarchy.newestURL.standardizedFileURL)
    }

    // MARK: - Helpers
    private func makeSUT(fileSystem: MockFileSystem = MockFileSystem()) -> DerivedDataLocator {
        DerivedDataLocator(fileSystem: fileSystem)
    }

    private func derivedDataRootURL(for libraryURL: URL) -> URL {
        libraryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("Xcode", isDirectory: true)
            .appendingPathComponent("DerivedData", isDirectory: true)
    }

    private func prepareDerivedDataHierarchy(projectName: String) throws -> (
        libraryURL: URL,
        derivedDataRoot: URL,
        newestURL: URL,
        olderURL: URL,
        unrelatedURL: URL,
        cleanupURL: URL
    ) {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let derivedDataRoot = derivedDataRootURL(for: baseURL)
        try FileManager.default.createDirectory(at: derivedDataRoot, withIntermediateDirectories: true)

        let olderURL = derivedDataRoot.appendingPathComponent("\(projectName)-ABC123", isDirectory: true)
        let newestURL = derivedDataRoot.appendingPathComponent("\(projectName)-XYZ789", isDirectory: true)
        let unrelatedURL = derivedDataRoot.appendingPathComponent("AnotherProject-000", isDirectory: true)

        try FileManager.default.createDirectory(at: olderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newestURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedURL, withIntermediateDirectories: true)

        try FileManager.default.setAttributes([
            .modificationDate: Date(timeIntervalSince1970: 1000)
        ], ofItemAtPath: olderURL.path)
        try FileManager.default.setAttributes([
            .modificationDate: Date(timeIntervalSince1970: 2000)
        ], ofItemAtPath: newestURL.path)

        return (
            libraryURL: baseURL,
            derivedDataRoot: derivedDataRoot,
            newestURL: newestURL,
            olderURL: olderURL,
            unrelatedURL: unrelatedURL,
            cleanupURL: baseURL
        )
    }
}
