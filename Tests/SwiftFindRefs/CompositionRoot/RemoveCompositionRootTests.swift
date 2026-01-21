import Foundation
import Testing
@testable import SwiftFindRefs

@Suite("RemoveCompositionRoot Tests")
struct RemoveCompositionRootTests {
    @Test("test run with missing configuration file throws configuration error")
    func test_run_WithMissingConfiguration_throwsConfigurationError() async {
        // Given
        let fileSystem = MockFileSystem(currentDirectoryPath: "/mock/current/directory")
        let sut = makeRemoveSUT(
            fileSystem: fileSystem,
            removerFactory: { _ in MockRemover(result: []) }
        )

        // When
        let error = await #expect(throws: ConfigurationLoaderError.self) {
            try await sut.run()
        }

        // Then
        guard case .configurationFileNotFound(let path) = error else {
            Issue.record("Expected .configurationFileNotFound but received \(error)")
            return
        }
        #expect(path == "/mock/current/directory/.swift-find-refs.json")
    }

    @Test("test run prints updated files count when nothing updated")
    func test_run_WhenNoUpdates_PrintsUpdatedCount() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configPath = tempDir.appendingPathComponent(".swift-find-refs.json")
        try "{\"unusedImports\":{\"ignoredModules\":[]}}".write(to: configPath, atomically: true, encoding: .utf8)

        let derivedDataPath = "/mock/DerivedData/IndexStoreDB"
        let currentDirPath = tempDir.path.hasSuffix("/") ? tempDir.path : tempDir.path + "/"
        let fileSystem = MockFileSystem(
            fileExistsResults: [derivedDataPath: true, configPath.path: true],
            currentDirectoryPath: currentDirPath
        )
        var printMessages: [String] = []
        let sut = makeRemoveSUT(
            fileSystem: fileSystem,
            print: { printMessages.append($0) },
            removerFactory: { _ in MockRemover(result: []) }
        )

        // When
        try await sut.run()

        // Then
        #expect(printMessages.contains("✅ Updated 0 files"))
    }

    @Test("test run prints updated files when remover returns results")
    func test_run_WhenUpdatesExist_PrintsUpdatedFiles() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configPath = tempDir.appendingPathComponent(".swift-find-refs.json")
        try "{\"unusedImports\":{\"ignoredModules\":[]}}".write(to: configPath, atomically: true, encoding: .utf8)

        let derivedDataPath = "/mock/DerivedData/IndexStoreDB"
        let currentDirPath = tempDir.path.hasSuffix("/") ? tempDir.path : tempDir.path + "/"
        let fileSystem = MockFileSystem(
            fileExistsResults: [derivedDataPath: true, configPath.path: true],
            currentDirectoryPath: currentDirPath
        )
        var printMessages: [String] = []
        var vPrintMessages: [String] = []
        let updatedFiles = ["/mock/FileA.swift", "/mock/FileB.swift"]
        let sut = makeRemoveSUT(
            fileSystem: fileSystem,
            print: { printMessages.append($0) },
            vPrint: { vPrintMessages.append($0) },
            removerFactory: { _ in
                MockRemover(result: updatedFiles)
            }
        )

        // When
        try await sut.run()

        // Then
        #expect(printMessages.contains("✅ Updated 2 files"))
        #expect(vPrintMessages.contains("Updated files:"))
        #expect(vPrintMessages.contains("/mock/FileA.swift"))
        #expect(vPrintMessages.contains("/mock/FileB.swift"))
    }

    @Test("test root uses provided root path when root path has trailing slash")
    func test_root_WithProvidedRootPathEndingWithSlash_usesRootPathAsIs() {
        // Given
        let fileSystem = MockFileSystem(currentDirectoryPath: "/mock/current/directory")
        let sut = RemoveCompositionRoot(
            rootPath: "/my/project/",
            print: { _ in },
            vPrint: { _ in },
            fileSystem: fileSystem,
            removerFactory: { _ in MockRemover(result: []) }
        )

        // Then
        #expect(sut.root == "/my/project/")
    }

    @Test("test root appends slash when provided root path has no trailing slash")
    func test_root_WithProvidedRootPathMissingTrailingSlash_appendsSlash() {
        // Given
        let fileSystem = MockFileSystem(currentDirectoryPath: "/mock/current/directory")
        let sut = RemoveCompositionRoot(
            rootPath: "/my/project",
            print: { _ in },
            vPrint: { _ in },
            fileSystem: fileSystem,
            removerFactory: { _ in MockRemover(result: []) }
        )

        // Then
        #expect(sut.root == "/my/project/")
    }

    @Test("test root uses current directory path when root path is nil and current directory has trailing slash")
    func test_root_WithNilRootPathAndCurrentDirectoryEndingWithSlash_usesCurrentDirectoryAsIs() {
        // Given
        let fileSystem = MockFileSystem(currentDirectoryPath: "/mock/current/directory/")
        let sut = RemoveCompositionRoot(
            rootPath: nil,
            print: { _ in },
            vPrint: { _ in },
            fileSystem: fileSystem,
            removerFactory: { _ in MockRemover(result: []) }
        )

        // Then
        #expect(sut.root == "/mock/current/directory/")
    }

    @Test("test root appends slash when root path is nil and current directory has no trailing slash")
    func test_root_WithNilRootPathAndCurrentDirectoryMissingTrailingSlash_appendsSlash() {
        // Given
        let fileSystem = MockFileSystem(currentDirectoryPath: "/mock/current/directory")
        let sut = RemoveCompositionRoot(
            rootPath: nil,
            print: { _ in },
            vPrint: { _ in },
            fileSystem: fileSystem,
            removerFactory: { _ in MockRemover(result: []) }
        )

        // Then
        #expect(sut.root == "/mock/current/directory/")
    }

    private func makeRemoveSUT(
        fileSystem: MockFileSystem,
        print: @escaping (String) -> Void = { _ in },
        vPrint: @escaping (String) -> Void = { _ in },
        removerFactory: @escaping (Configuration) -> UnnecessaryRemoving
    ) -> RemoveCompositionRoot {
        RemoveCompositionRoot(
            rootPath: nil,
            print: print,
            vPrint: vPrint,
            fileSystem: fileSystem,
            removerFactory: removerFactory
        )
    }
}
