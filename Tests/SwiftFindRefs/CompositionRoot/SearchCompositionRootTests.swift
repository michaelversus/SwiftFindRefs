import Testing
@testable import SwiftFindRefs

@Suite("SearchCompositionRoot Tests")
struct SearchCompositionRootTests {

    // MARK: - Tests

    @Test("test run with missing inputs throws missing inputs error")
    func test_run_WithMissingInputs_throwsMissingInputsError() async {
        // Given
        let fileSystem = MockFileSystem()
        let sut = makeSearchSUT(
            projectName: nil,
            dataStorePath: nil,
            symbolType: "class",
            fileSystem: fileSystem
        )

        // When
        let error = await #expect(throws: DerivedDataLocatorError.self) {
            try await sut.run()
        }

        // Then
        guard case .missingInputs = error else {
            Issue.record("Expected .missingInputs but received \(error)")
            return
        }
    }

    @Test("test run with invalid derived data path throws invalid path error")
    func test_run_WithInvalidDerivedDataPath_throwsInvalidPathError() async {
        // Given
        let invalidPath = "/invalid/DerivedData"
        let fileSystem = MockFileSystem(fileExistsResults: [invalidPath: false])
        let sut = makeSearchSUT(
            projectName: "Project",
            dataStorePath: invalidPath,
            symbolType: "class",
            fileSystem: fileSystem
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

    @Test("test run with nil symbol type logs fallback before index store failure")
    func test_run_WithNilSymbolType_logsFallbackBeforeIndexStoreFailure() async throws {
        // Given
        let dataStorePath = "/tmp/nonexistent/IndexStoreDB"
        let fileSystem = MockFileSystem(fileExistsResults: [dataStorePath: true])
        var standardMessages: [String] = []
        var verboseMessages: [String] = []
        let sut = makeSearchSUT(
            projectName: "Project",
            dataStorePath: dataStorePath,
            symbolType: nil,
            fileSystem: fileSystem,
            print: { standardMessages.append($0) },
            vPrint: { verboseMessages.append($0) }
        )

        // When
        _ = await #expect(throws: (any Error).self) {
            try await sut.run()
        }

        // Then
        #expect(verboseMessages.contains("Using DataStore path: \(dataStorePath)"))
        let searchMessage = try #require(standardMessages.first { $0.contains("Searching for references") })
        #expect(searchMessage.contains("symbol 'MySymbol'"))
        #expect(searchMessage.contains("of type 'any'"))
    }

    // MARK: - Helpers

    private func makeSearchSUT(
        projectName: String?,
        dataStorePath: String?,
        symbolName: String = "MySymbol",
        symbolType: String? = "class",
        fileSystem: MockFileSystem,
        print: @escaping (String) -> Void = { _ in },
        vPrint: @escaping (String) -> Void = { _ in }
    ) -> SearchCompositionRoot {
        SearchCompositionRoot(
            projectName: projectName,
            dataStorePath: dataStorePath,
            symbolName: symbolName,
            symbolType: symbolType,
            print: print,
            vPrint: vPrint,
            fileSystem: fileSystem,
            derivedDataLocator: DerivedDataLocator(fileSystem: fileSystem)
        )
    }
}

