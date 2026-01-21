import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("FileSystem Tests")
struct FileSystemTests {
    // MARK: - Tests

    @Test("test currentDirectoryPath returns file manager currentDirectoryPath")
    func test_currentDirectoryPath_ReturnsFileManagerCurrentDirectoryPath() {
        // Given
        let expectedPath = "/tmp/CurrentDirectory-\(UUID().uuidString)"
        let fileManager = TestFileManager(currentDirectoryPath: expectedPath)
        let sut = makeSUT(fileManager: fileManager)

        // When
        let result = sut.currentDirectoryPath

        // Then
        #expect(result == expectedPath)
    }

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

    @Test("test readFile returns file contents")
    func test_readFile_ReturnsContents() throws {
        // Given
        let fileURL = makeTempFileURL()
        let contents = "Hello\nWorld"
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        let sut = makeSUT(fileManager: FileManager.default)

        // When
        let result = try sut.readFile(atPath: fileURL.path)

        // Then
        #expect(result == contents)
    }

    @Test("test writeFile writes contents to disk")
    func test_writeFile_WritesContents() throws {
        // Given
        let fileURL = makeTempFileURL()
        let contents = "Line1\nLine2"
        let sut = makeSUT(fileManager: FileManager.default)

        // When
        try sut.writeFile(contents, toPath: fileURL.path)

        // Then
        let result = try String(contentsOf: fileURL)
        #expect(result == contents)
    }

    @Test("test readLines returns lines")
    func test_readLines_ReturnsLines() throws {
        // Given
        let fileURL = makeTempFileURL()
        let contents = "LineA\nLineB\nLineC"
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        let sut = makeSUT(fileManager: FileManager.default)

        // When
        let lines = try sut.readLines(atPath: fileURL.path)

        // Then
        #expect(lines == ["LineA", "LineB", "LineC"])
    }

    @Test("test readLines preserves empty lines including trailing ones")
    func test_readLines_PreservesEmptyLines() throws {
        // Given
        let fileURL = makeTempFileURL()
        // File with empty lines in middle and trailing empty lines
        let contents = "LineA\n\nLineB\n\n\n"
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        let sut = makeSUT(fileManager: FileManager.default)

        // When
        let lines = try sut.readLines(atPath: fileURL.path)

        // Then
        // components(separatedBy: .newlines) preserves all empty lines including trailing ones
        // "LineA\n\nLineB\n\n\n" should split to ["LineA", "", "LineB", "", "", ""]
        #expect(lines == ["LineA", "", "LineB", "", "", ""])
    }

    // MARK: - Helpers

    private func makeSUT(fileManager: FileManager) -> FileSystem {
        FileSystem(fileManager: fileManager)
    }

    private func makeTempFileURL() -> URL {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return directoryURL.appendingPathComponent("SwiftFindRefs-\(UUID().uuidString).txt")
    }
}

// MARK: - Test Doubles

private final class TestFileManager: FileManager {
    var fileExistsResults: [String: Bool]
    var libraryDirectoryURLs: [URL]?
    var homeDirectoryURL: URL
    var contentsResults: [URL: Result<[URL], Error>]
    var contentsCallArguments: (url: URL, keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions)?
    private let stubbedCurrentDirectoryPath: String?

    init(
        fileExistsResults: [String: Bool] = [:],
        libraryDirectoryURLs: [URL]? = nil,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        contentsResults: [URL: Result<[URL], Error>] = [:],
        currentDirectoryPath: String? = nil
    ) {
        self.fileExistsResults = fileExistsResults
        self.libraryDirectoryURLs = libraryDirectoryURLs
        self.homeDirectoryURL = homeDirectoryURL
        self.contentsResults = contentsResults
        self.stubbedCurrentDirectoryPath = currentDirectoryPath
        super.init()
    }

    override var currentDirectoryPath: String {
        stubbedCurrentDirectoryPath ?? super.currentDirectoryPath
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
