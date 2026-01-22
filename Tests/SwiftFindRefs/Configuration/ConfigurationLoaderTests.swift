import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("ConfigurationLoader Tests")
struct ConfigurationLoaderTests {

    // MARK: - Tests
    @Test("test loadConfiguration with absolute path uses absolute path and returns decoded configuration")
    func test_loadConfiguration_WithAbsolutePath_returnsDecodedConfiguration() throws {
        // Given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let configurationFileURL = temporaryDirectoryURL.appending(path: "configuration-absolute.json")
        let configurationFilePath = configurationFileURL.path
        let configurationJSON = """
        {"unusedImports": {"ignoredModules": ["A", "B"]}}
        """
        try configurationJSON.write(to: configurationFileURL, atomically: true, encoding: .utf8)

        let fileSystem = MockFileSystem(fileExistsResults: [configurationFilePath: true])
        var printedLines: [String] = []
        let sut = ConfigurationLoader(
            fileSystem: fileSystem,
            print: { printedLines.append($0) }
        )

        // When
        let configuration = try sut.loadConfiguration(at: configurationFilePath, root: "/not/used/")

        // Then
        #expect(configuration == Configuration(unusedImports: UnusedImportsConfiguration(ignoredModules: ["A", "B"], excludedDirectories: nil), unusedTestableImports: nil))
        #expect(fileSystem.actions.contains(.fileExists(atPath: configurationFilePath)))
        #expect(printedLines.contains("Loading configuration from: \(configurationFilePath)"))
    }

    @Test("test loadConfiguration with relative path prefixes root")
    func test_loadConfiguration_WithRelativePath_prefixesRoot() throws {
        // Given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let rootPath = temporaryDirectoryURL.path + "/"

        let configurationFilePath = rootPath + "configuration-relative.json"
        let configurationFileURL = URL(fileURLWithPath: configurationFilePath)
        let configurationJSON = """
        {"unusedImports": {"ignoredModules": []}}
        """
        try configurationJSON.write(to: configurationFileURL, atomically: true, encoding: .utf8)

        let fileSystem = MockFileSystem(fileExistsResults: [configurationFilePath: true])
        let sut = ConfigurationLoader(fileSystem: fileSystem, print: { _ in })

        // When
        _ = try sut.loadConfiguration(at: "configuration-relative.json", root: rootPath)

        // Then
        #expect(fileSystem.actions.contains(.fileExists(atPath: configurationFilePath)))
    }

    @Test("test loadConfiguration with nil path uses defaultPath")
    func test_loadConfiguration_WithNilPath_usesDefaultPath() throws {
        // Given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let rootPath = temporaryDirectoryURL.path + "/"

        let configurationFilePath = rootPath + ".swift-find-refs.json"
        let configurationFileURL = URL(fileURLWithPath: configurationFilePath)
        let configurationJSON = """
        {"unusedImports": {"ignoredModules": ["Ignored"]}}
        """
        try configurationJSON.write(to: configurationFileURL, atomically: true, encoding: .utf8)

        let fileSystem = MockFileSystem(fileExistsResults: [configurationFilePath: true])
        let sut = ConfigurationLoader(fileSystem: fileSystem, print: { _ in })

        // When
        let configuration = try sut.loadConfiguration(at: nil, root: rootPath)

        // Then
        #expect(configuration.unusedImports?.ignoredModules == ["Ignored"])
        #expect(fileSystem.actions.contains(.fileExists(atPath: configurationFilePath)))
    }

    @Test("test loadConfiguration with nil path uses custom defaultPath")
    func test_loadConfiguration_WithNilPathAndCustomDefaultPath_usesCustomDefaultPath() throws {
        // Given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let rootPath = temporaryDirectoryURL.path + "/"
        let customDefaultPath = "custom-config.json"

        let configurationFilePath = rootPath + customDefaultPath
        let configurationFileURL = URL(fileURLWithPath: configurationFilePath)
        let configurationJSON = """
        {"unusedImports": {"ignoredModules": []}}
        """
        try configurationJSON.write(to: configurationFileURL, atomically: true, encoding: .utf8)

        let fileSystem = MockFileSystem(fileExistsResults: [configurationFilePath: true])
        let sut = ConfigurationLoader(
            fileSystem: fileSystem,
            defaultPath: customDefaultPath,
            print: { _ in }
        )

        // When
        _ = try sut.loadConfiguration(at: nil, root: rootPath)

        // Then
        #expect(fileSystem.actions.contains(.fileExists(atPath: configurationFilePath)))
    }

    @Test("test loadConfiguration when file is missing throws configurationFileNotFound")
    func test_loadConfiguration_WhenFileIsMissing_throwsConfigurationFileNotFound() {
        // Given
        let rootPath = "/mock/root/"
        let relativePath = "missing.json"
        let expectedResolvedPath = rootPath + relativePath

        let fileSystem = MockFileSystem(fileExistsResults: [expectedResolvedPath: false])
        let sut = ConfigurationLoader(fileSystem: fileSystem, print: { _ in })

        // When
        let error = #expect(throws: ConfigurationLoaderError.self) {
            _ = try sut.loadConfiguration(at: relativePath, root: rootPath)
        }

        // Then
        #expect(error == .configurationFileNotFound(expectedResolvedPath))
        #expect(fileSystem.actions.contains(.fileExists(atPath: expectedResolvedPath)))
    }

    @Test("test loadConfiguration with invalid json propagates decoding error")
    func test_loadConfiguration_WithInvalidJSON_throwsError() {
        // Given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let configurationFileURL = temporaryDirectoryURL.appending(path: "configuration-invalid.json")
        let configurationFilePath = configurationFileURL.path
        let invalidJSON = "{" // invalid
        try? invalidJSON.write(to: configurationFileURL, atomically: true, encoding: .utf8)

        let fileSystem = MockFileSystem(fileExistsResults: [configurationFilePath: true])
        let sut = ConfigurationLoader(fileSystem: fileSystem, print: { _ in })

        // When / Then
        _ = #expect(throws: (any Error).self) {
            _ = try sut.loadConfiguration(at: configurationFilePath, root: "/")
        }
    }
}
