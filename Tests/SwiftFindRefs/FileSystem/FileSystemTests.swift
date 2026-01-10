import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("FileSystem Tests")
struct FileSystemTests {
    // MARK: - Tests

    @Test("test fileExists with existing path returns true")
    func test_fileExists_WithExistingPath_returnsTrue() {
        // Given
        let path = "/tmp/Existing-\(UUID().uuidString)"
        let fileManager = TestFileManager(fileExistsResults: [path: true])
        let sut = makeSUT(fileManager: fileManager)

        // When
        let result = sut.fileExists(atPath: path)

        // Then
        #expect(result == true)
    }

    @Test("test fileExists with missing path returns false")
    func test_fileExists_WithMissingPath_returnsFalse() {
        // Given
        let path = "/tmp/Missing-\(UUID().uuidString)"
        let fileManager = TestFileManager(fileExistsResults: [:])
        let sut = makeSUT(fileManager: fileManager)

        // When
        let result = sut.fileExists(atPath: path)

        // Then
        #expect(result == false)
    }

    @Test("test libraryDirectory with provided library path returns first URL")
    func test_libraryDirectory_WithProvidedLibrary_returnsFirstMatch() {
        // Given
        let expectedURL = URL(fileURLWithPath: "/tmp/Library-\(UUID().uuidString)", isDirectory: true)
        let fileManager = TestFileManager(libraryDirectoryURLs: [expectedURL])
        let sut = makeSUT(fileManager: fileManager)

        // When
        let result = sut.libraryDirectory()

        // Then
        #expect(result == expectedURL)
    }

    @Test("test libraryDirectory without provided library falls back to home library path")
    func test_libraryDirectory_WithoutProvidedLibrary_returnsHomeLibraryPath() {
        // Given
        let homeURL = URL(fileURLWithPath: "/tmp/Home-\(UUID().uuidString)", isDirectory: true)
        let fileManager = TestFileManager(libraryDirectoryURLs: [], homeDirectoryURL: homeURL)
        let sut = makeSUT(fileManager: fileManager)

        // When
        let result = sut.libraryDirectory()

        // Then
        let expectedURL = homeURL.appendingPathComponent("Library", isDirectory: true)
        #expect(result == expectedURL)
    }

    @Test("test contentsOfDirectory returns file manager results")
    func test_contentsOfDirectory_WithExistingEntries_returnsManagerResults() throws {
        // Given
        let directoryURL = URL(fileURLWithPath: "/tmp/Directory-\(UUID().uuidString)", isDirectory: true)
        let childURLs = [
            directoryURL.appendingPathComponent("A"),
            directoryURL.appendingPathComponent("B")
        ]
        let fileManager = TestFileManager(
            contentsResults: [directoryURL: .success(childURLs)]
        )
        let sut = makeSUT(fileManager: fileManager)
        let keys: [URLResourceKey]? = [.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]

        // When
        let result = try sut.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: keys, options: options)

        // Then
        #expect(result == childURLs)
        #expect(fileManager.contentsCallArguments?.url == directoryURL)
        #expect(fileManager.contentsCallArguments?.keys?.contains(.isDirectoryKey) == true)
        #expect(fileManager.contentsCallArguments?.options == options)
    }

    @Test("test contentsOfDirectory propagates file manager errors")
    func test_contentsOfDirectory_WhenFileManagerThrows_throwsSameError() {
        // Given
        let directoryURL = URL(fileURLWithPath: "/tmp/Directory-\(UUID().uuidString)", isDirectory: true)
        let fileManager = TestFileManager(
            contentsResults: [directoryURL: .failure(TestError.sample)]
        )
        let sut = makeSUT(fileManager: fileManager)

        // When
        let error = #expect(throws: TestError.self) {
            _ = try sut.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [])
        }

        // Then
        #expect(error == .sample)
    }

    // MARK: - Helpers

    private func makeSUT(fileManager: FileManager) -> FileSystem {
        FileSystem(fileManager: fileManager)
    }
}

// MARK: - Test Doubles

private enum TestError: Error, Equatable {
    case sample
}

private final class TestFileManager: FileManager {
    var fileExistsResults: [String: Bool]
    var libraryDirectoryURLs: [URL]?
    var homeDirectoryURL: URL
    var contentsResults: [URL: Result<[URL], Error>]
    var contentsCallArguments: (url: URL, keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions)?

    init(
        fileExistsResults: [String: Bool] = [:],
        libraryDirectoryURLs: [URL]? = nil,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        contentsResults: [URL: Result<[URL], Error>] = [:]
    ) {
        self.fileExistsResults = fileExistsResults
        self.libraryDirectoryURLs = libraryDirectoryURLs
        self.homeDirectoryURL = homeDirectoryURL
        self.contentsResults = contentsResults
        super.init()
    }

    override func fileExists(atPath path: String) -> Bool {
        fileExistsResults[path] ?? false
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        if let libraryDirectoryURLs {
            return libraryDirectoryURLs
        }
        return super.urls(for: directory, in: domainMask)
    }

    override var homeDirectoryForCurrentUser: URL {
        homeDirectoryURL
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        contentsCallArguments = (url, keys, mask)
        if let result = contentsResults[url] {
            return try result.get()
        }
        return try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }
}
