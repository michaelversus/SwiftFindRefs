import Testing
@testable import SwiftFindRefs

@Suite("UnnecessaryTestableRewriter Tests")
struct UnnecessaryTestableRewriterTests {
    @Test("rewrites @testable imports in-place")
    func test_rewritesTestableImports() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        let contents = """
        @testable import ModuleA
        import ModuleB
        @testable import ModuleC
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleA", "ModuleC"]])

        // Then
        #expect(updated == [filePath])
        let written = try #require(fileSystem.writtenFiles[filePath])
        #expect(written.contains("import ModuleA"))
        #expect(written.contains("import ModuleC"))
        #expect(!written.contains("@testable import ModuleA"))
        #expect(!written.contains("@testable import ModuleC"))
    }

    @Test("skips rewrite when no changes needed")
    func test_skipsRewriteWhenNoChanges() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        let contents = """
        import ModuleA
        import ModuleB
        """
        let fileSystem = MockFileSystem(readFileResults: [filePath: contents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleC"]])

        // Then
        #expect(updated.isEmpty)
        #expect(fileSystem.writtenFiles.isEmpty)
    }

    @Test("preserves empty lines when rewriting @testable imports")
    func test_preservesEmptyLines() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        // File with empty lines at the beginning, middle, end, and multiple consecutive empty lines
        let originalContents = """
import Foundation

@testable import ModuleA

import ModuleB

@testable import ModuleC

class TestClass {
}

"""
        let fileSystem = MockFileSystem(readFileResults: [filePath: originalContents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleA", "ModuleC"]])

        // Then
        #expect(updated == [filePath])
        let written = try #require(fileSystem.writtenFiles[filePath])
        
        // Split both original and written into lines to compare structure
        let originalLines = originalContents.components(separatedBy: .newlines)
        let writtenLines = written.components(separatedBy: .newlines)
        
        // The number of lines should match (preserving empty lines)
        #expect(writtenLines.count == originalLines.count)
        
        // Verify that empty lines are preserved at their original positions
        for (index, originalLine) in originalLines.enumerated() {
            let writtenLine = writtenLines[index]
            if originalLine.isEmpty {
                // Empty lines must remain empty
                #expect(writtenLine.isEmpty, "Empty line at index \(index) was not preserved")
            } else if originalLine.trimmingCharacters(in: .whitespaces).hasPrefix("@testable import ModuleA") {
                // This line should be rewritten
                #expect(writtenLine.trimmingCharacters(in: .whitespaces) == "import ModuleA")
            } else if originalLine.trimmingCharacters(in: .whitespaces).hasPrefix("@testable import ModuleC") {
                // This line should be rewritten
                #expect(writtenLine.trimmingCharacters(in: .whitespaces) == "import ModuleC")
            } else {
                // All other lines should remain unchanged
                #expect(writtenLine == originalLine, "Line at index \(index) was modified: expected '\(originalLine)', got '\(writtenLine)'")
            }
        }
        
        // Verify the imports were changed
        #expect(written.contains("import ModuleA"))
        #expect(written.contains("import ModuleC"))
        #expect(!written.contains("@testable import ModuleA"))
        #expect(!written.contains("@testable import ModuleC"))
    }

    @Test("preserves trailing empty lines and newlines")
    func test_preservesTrailingEmptyLines() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        // File ending with multiple empty lines and a newline
        let originalContents = """
@testable import ModuleA
class TestClass {
}

"""
        let fileSystem = MockFileSystem(readFileResults: [filePath: originalContents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleA"]])

        // Then
        #expect(updated == [filePath])
        let written = try #require(fileSystem.writtenFiles[filePath])
        
        // Split both original and written into lines to compare structure
        let originalLines = originalContents.components(separatedBy: .newlines)
        let writtenLines = written.components(separatedBy: .newlines)
        
        // The number of lines should match exactly (including trailing empty lines)
        #expect(writtenLines.count == originalLines.count, 
                "Line count mismatch: original has \(originalLines.count) lines, written has \(writtenLines.count) lines")
        
        // Verify trailing empty lines are preserved
        // Original: ["@testable import ModuleA", "class TestClass {", "", ""]
        // Written should have the same structure
        for (index, originalLine) in originalLines.enumerated() {
            let writtenLine = writtenLines[index]
            if originalLine.isEmpty {
                #expect(writtenLine.isEmpty, "Empty line at index \(index) was not preserved")
            }
        }
        
        // Verify the last line is empty (trailing newline creates an empty line)
        if !originalLines.isEmpty {
            let lastOriginalLine = originalLines[originalLines.count - 1]
            let lastWrittenLine = writtenLines[writtenLines.count - 1]
            #expect(lastWrittenLine == lastOriginalLine, 
                    "Last line mismatch: expected '\(lastOriginalLine)', got '\(lastWrittenLine)'")
        }
    }

    @Test("preserves multiple consecutive empty lines")
    func test_preservesMultipleConsecutiveEmptyLines() async throws {
        // Given
        let filePath = "/mock/Test.swift"
        // File with multiple consecutive empty lines
        let originalContents = """
import Foundation


@testable import ModuleA


import ModuleB
"""
        let fileSystem = MockFileSystem(readFileResults: [filePath: originalContents])
        let sut = UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { _ in })

        // When
        let updated = try await sut.rewriteFiles([filePath: ["ModuleA"]])

        // Then
        #expect(updated == [filePath])
        let written = try #require(fileSystem.writtenFiles[filePath])
        
        // Split both original and written into lines
        let originalLines = originalContents.components(separatedBy: .newlines)
        let writtenLines = written.components(separatedBy: .newlines)
        
        // Verify exact line count match
        #expect(writtenLines.count == originalLines.count, 
                "Line count mismatch: original has \(originalLines.count) lines, written has \(writtenLines.count) lines")
        
        // Verify consecutive empty lines are preserved
        // Check that empty lines at specific indices are preserved
        for (index, originalLine) in originalLines.enumerated() {
            let writtenLine = writtenLines[index]
            if originalLine.isEmpty {
                #expect(writtenLine.isEmpty, "Empty line at index \(index) was not preserved")
            } else if originalLine.trimmingCharacters(in: .whitespaces).hasPrefix("@testable import ModuleA") {
                #expect(writtenLine.trimmingCharacters(in: .whitespaces) == "import ModuleA")
            } else {
                #expect(writtenLine == originalLine, "Line at index \(index) was modified: expected '\(originalLine)', got '\(writtenLine)'")
            }
        }
        
        // Verify we have consecutive empty lines preserved
        let originalEmptyLineIndices = originalLines.enumerated().compactMap { $0.element.isEmpty ? $0.offset : nil }
        let writtenEmptyLineIndices = writtenLines.enumerated().compactMap { $0.element.isEmpty ? $0.offset : nil }
        #expect(originalEmptyLineIndices == writtenEmptyLineIndices, 
                "Empty line positions don't match: original at \(originalEmptyLineIndices), written at \(writtenEmptyLineIndices)")
    }
}
