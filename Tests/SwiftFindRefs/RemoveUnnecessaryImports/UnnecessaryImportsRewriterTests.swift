import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryImportsRewriter Tests")
struct UnnecessaryImportsRewriterTests {

    // MARK: - Tests

    @Test("test rewriteFiles with unused imports removes matching import statements and writes updated file")
    func test_rewriteFiles_WithUnusedImports_removesMatchingImportStatementsAndWritesUpdatedFile() async throws {
        // Given
        let filePath = "/tmp/MyFile.swift"
        let fileContents = """
        import Foundation
        import ModuleA
        import ModuleB

        struct Example {}
        """

        let fileSystem = MockFileSystem(readFileResults: [filePath: fileContents])
        let sut = UnnecessaryImportsRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updatedFiles = try await sut.rewriteFiles([filePath: ["Foundation", "ModuleB"]])

        // Then
        #expect(Set(updatedFiles) == [filePath])

        let writtenContents = try #require(fileSystem.writtenFiles[filePath])
        #expect(writtenContents.contains("import ModuleA") == true)
        #expect(writtenContents.contains("import Foundation") == false)
        #expect(writtenContents.contains("import ModuleB") == false)
        #expect(writtenContents.contains("struct Example") == true)
    }

    @Test("test rewriteFiles with unused testable import removes matching testable import statement")
    func test_rewriteFiles_WithUnusedTestableImport_removesMatchingTestableImportStatement() async throws {
        // Given
        let filePath = "/tmp/MyTestFile.swift"
        let fileContents = """
        @testable import ModuleATests
        import Foundation

        struct Example {}
        """

        let fileSystem = MockFileSystem(readFileResults: [filePath: fileContents])
        let sut = UnnecessaryImportsRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updatedFiles = try await sut.rewriteFiles([filePath: ["Foundation"]])

        // Then
        #expect(Set(updatedFiles) == [filePath])

        let writtenContents = try #require(fileSystem.writtenFiles[filePath])
        #expect(writtenContents.contains("@testable import ModuleATests") == true)
        #expect(writtenContents.contains("import Foundation") == false)
    }

    @Test("test rewriteFiles with comments after import handles module name correctly")
    func test_rewriteFiles_WithCommentsAfterImport_extractsModuleNameAndRemovesUnusedImport() async throws {
        // Given
        let filePath = "/tmp/Comments.swift"
        let fileContents = """
        import Networking//comment
        import Foundation  // note

        struct Example {}
        """

        let fileSystem = MockFileSystem(readFileResults: [filePath: fileContents])
        let sut = UnnecessaryImportsRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        _ = try await sut.rewriteFiles([filePath: ["Foundation"]])

        // Then
        let writtenContents = try #require(fileSystem.writtenFiles[filePath])
        #expect(writtenContents.contains("import Networking") == true)
        #expect(writtenContents.contains("import Foundation") == false)
    }

    @Test("test rewriteFiles without unused imports returns empty and does not write")
    func test_rewriteFiles_WithoutUnusedImports_returnsEmptyAndDoesNotWrite() async throws {
        // Given
        let filePath = "/tmp/NoChanges.swift"
        let fileContents = """
        import Foundation

        struct Example {}
        """

        let fileSystem = MockFileSystem(readFileResults: [filePath: fileContents])
        let sut = UnnecessaryImportsRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updatedFiles = try await sut.rewriteFiles([filePath: ["Foundation"]])

        // Then
        #expect(Set(updatedFiles) == [filePath])
        let writtenContents = try #require(fileSystem.writtenFiles[filePath])
        #expect(writtenContents.contains("import Foundation") == false)
        #expect(writtenContents.contains("struct Example") == true)
    }

    @Test("test rewriteFiles when readLines throws propagates error")
    func test_rewriteFiles_WhenReadLinesThrows_propagatesError() async {
        // Given
        let filePath = "/tmp/ReadError.swift"
        let fileSystem = MockFileSystem(readFileResults: [filePath: "import Foundation"], readFileError: MockError.readFailure)
        let sut = UnnecessaryImportsRewriter(fileSystem: fileSystem, print: { _ in })

        // When / Then
        _ = await #expect(throws: MockError.self) {
            _ = try await sut.rewriteFiles([filePath: ["Foundation"]])
        }
    }

    @Test("test rewriteFiles when writeFile throws propagates error")
    func test_rewriteFiles_WhenWriteFileThrows_propagatesError() async {
        // Given
        let filePath = "/tmp/WriteError.swift"
        let fileContents = """
        import Foundation
        import ModuleA

        struct Example {}
        """

        let fileSystem = MockFileSystem(
            readFileResults: [filePath: fileContents],
            writeFileError: MockError.writeFailure
        )
        let sut = UnnecessaryImportsRewriter(fileSystem: fileSystem, print: { _ in })

        // When / Then
        _ = await #expect(throws: MockError.self) {
            _ = try await sut.rewriteFiles([filePath: ["Foundation"]])
        }
    }
}

// MARK: - Helpers

private enum MockError: Error {
    case readFailure
    case writeFailure
}
