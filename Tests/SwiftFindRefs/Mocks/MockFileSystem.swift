import Foundation
@testable import SwiftFindRefs

final class MockFileSystem: FileSystemProvider {

    private let fileExistsResults: [String: Bool]
    private let libraryDirectoryURL: URL
    private let contentsOfDirectoryResults: [URL: [URL]]
    private let contentsOfDirectoryError: Error?
    private let readFileResults: [String: String]
    private let readFileError: Error?
    private let writeFileError: Error?
    let currentDirectoryPath: String
    var actions: [Action] = []
    var writtenFiles: [String: String] = [:]

    enum Action: Equatable {
        case fileExists(atPath: String)
        case libraryDirectory
        case contentsOfDirectory(at: URL, includingPropertiesForKeys: [URLResourceKey])
        case readFile(atPath: String)
        case readLines(atPath: String)
        case writeFile(atPath: String, contents: String)
    }

    init(
        fileExistsResults: [String: Bool] = [:],
        libraryDirectoryURL: URL = URL(fileURLWithPath: "/mock/library/directory"),
        contentsOfDirectoryResults: [URL: [URL]] = [:],
        contentsOfDirectoryError: Error? = nil,
        readFileResults: [String: String] = [:],
        readFileError: Error? = nil,
        writeFileError: Error? = nil,
        currentDirectoryPath: String = "/mock/current/directory"
    ) {
        self.fileExistsResults = fileExistsResults
        self.libraryDirectoryURL = libraryDirectoryURL
        self.contentsOfDirectoryResults = contentsOfDirectoryResults
        self.contentsOfDirectoryError = contentsOfDirectoryError
        self.readFileResults = readFileResults
        self.readFileError = readFileError
        self.writeFileError = writeFileError
        self.currentDirectoryPath = currentDirectoryPath
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

    func readFile(atPath path: String) throws -> String {
        actions.append(.readFile(atPath: path))
        if let error = readFileError {
            throw error
        }
        return readFileResults[path] ?? ""
    }

    func readLines(atPath path: String) throws -> [String] {
        actions.append(.readLines(atPath: path))
        if let error = readFileError {
            throw error
        }
        let contents = readFileResults[path] ?? ""
        return contents.components(separatedBy: .newlines)
    }

    func writeFile(_ contents: String, toPath path: String) throws {
        actions.append(.writeFile(atPath: path, contents: contents))
        if let error = writeFileError {
            throw error
        }
        writtenFiles[path] = contents
    }
}
