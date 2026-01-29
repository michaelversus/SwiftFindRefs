import Testing
@testable import SwiftFindRefs

@Suite("RemoveCompositionRoot Tests")
struct RemoveCompositionRootTests {
    @Test("test run with invalid derived data path throws invalid path error")
    func test_run_WithInvalidDerivedDataPath_throwsInvalidPathError() async {
        // Given
        let invalidPath = "/invalid/DerivedData"
        let fileSystem = MockFileSystem(fileExistsResults: [invalidPath: false])
        let sut = makeRemoveSUT(
            projectName: "Project",
            dataStorePath: invalidPath,
            excludeCompilationConditionals: false,
            fileSystem: fileSystem,
            removerFactory: { _ in MockRemover(result: []) }
        )

        // When
        let error = await #expect(throws: DataStorePathValidationError.self) {
            try await sut.run()
        }

        // Then
        guard case .invalidPath(let path) = error else {
            Issue.record("Expected .invalidPath but received \(error)")
            return
        }
        #expect(path == invalidPath)
    }

    @Test("test run prints updated files count when nothing updated")
    func test_run_WhenNoUpdates_PrintsUpdatedCount() async throws {
        // Given
        let dataStorePath = "/mock/DerivedData/IndexStoreDB"
        let fileSystem = MockFileSystem(fileExistsResults: [dataStorePath: true])
        var printMessages: [String] = []
        let sut = makeRemoveSUT(
            projectName: "Project",
            dataStorePath: dataStorePath,
            excludeCompilationConditionals: false,
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
        let dataStorePath = "/mock/DerivedData/IndexStoreDB"
        let fileSystem = MockFileSystem(fileExistsResults: [dataStorePath: true])
        var printMessages: [String] = []
        var vPrintMessages: [String] = []
        let updatedFiles = ["/mock/FileA.swift", "/mock/FileB.swift"]
        var receivedIndexStorePath: String?
        let sut = makeRemoveSUT(
            projectName: "Project",
            dataStorePath: dataStorePath,
            excludeCompilationConditionals: false,
            fileSystem: fileSystem,
            print: { printMessages.append($0) },
            vPrint: { vPrintMessages.append($0) },
            removerFactory: { path in
                receivedIndexStorePath = path
                return MockRemover(result: updatedFiles)
            }
        )

        // When
        try await sut.run()

        // Then
        #expect(receivedIndexStorePath == "/mock/DerivedData/IndexStoreDB")
        #expect(printMessages.contains("✅ Updated 2 files"))
        #expect(vPrintMessages.contains("Updated files:"))
        #expect(vPrintMessages.contains("/mock/FileA.swift"))
        #expect(vPrintMessages.contains("/mock/FileB.swift"))
    }

    private func makeRemoveSUT(
        projectName: String?,
        dataStorePath: String?,
        excludeCompilationConditionals: Bool,
        fileSystem: MockFileSystem,
        print: @escaping (String) -> Void = { _ in },
        vPrint: @escaping (String) -> Void = { _ in },
        removerFactory: @escaping (String) -> UnnecessaryTestableRemoving
    ) -> RemoveCompositionRoot {
        RemoveCompositionRoot(
            projectName: projectName,
            dataStorePath: dataStorePath,
            excludeCompilationConditionals: excludeCompilationConditionals,
            print: print,
            vPrint: vPrint,
            fileSystem: fileSystem,
            derivedDataLocator: DerivedDataLocator(fileSystem: fileSystem),
            removerFactory: removerFactory
        )
    }
}

private struct MockRemover: UnnecessaryTestableRemoving {
    let result: [String]

    func run() async throws -> [String] {
        result
    }
}
