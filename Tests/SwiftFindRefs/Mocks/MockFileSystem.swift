import Foundation
@testable import SwiftFindRefs

final class MockFileSystem: FileSystemProvider {

    private let fileExistsResults: [String: Bool]
    private let libraryDirectoryURL: URL
    private let contentsOfDirectoryResults: [URL: [URL]]
    private let contentsOfDirectoryError: Error?
    var actions: [Action] = []

    enum Action: Equatable {
        case fileExists(atPath: String)
        case libraryDirectory
        case contentsOfDirectory(at: URL, includingPropertiesForKeys: [URLResourceKey])
    }

    init(
        fileExistsResults: [String: Bool] = [:],
        libraryDirectoryURL: URL = URL(fileURLWithPath: "/mock/library/directory"),
        contentsOfDirectoryResults: [URL: [URL]] = [:],
        contentsOfDirectoryError: Error? = nil
    ) {
        self.fileExistsResults = fileExistsResults
        self.libraryDirectoryURL = libraryDirectoryURL
        self.contentsOfDirectoryResults = contentsOfDirectoryResults
        self.contentsOfDirectoryError = contentsOfDirectoryError
    }

    func fileExists(atPath path: String) -> Bool {
        actions.append(.fileExists(atPath: path))
        return fileExistsResults[path] ?? false
    }
    
    func libraryDirectory() -> URL {
        actions.append(.libraryDirectory)
        return libraryDirectoryURL
    }
    
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        actions.append(.contentsOfDirectory(at: url, includingPropertiesForKeys: keys ?? []))
        if let error = contentsOfDirectoryError {
            throw error
        }
        return contentsOfDirectoryResults[url] ?? []
    }
}
