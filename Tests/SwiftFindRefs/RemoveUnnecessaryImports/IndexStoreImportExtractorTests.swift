import IndexStore
import Testing
@testable import SwiftFindRefs

@Suite("IndexStoreImportExtractor Tests")
struct IndexStoreImportExtractorTests {

    @Test("imports with invalid occurences returns empty")
    func test_imports_WithInvalidOccurrences_ReturnsEmpty() {
        // Given
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            "": [
                OccurrenceSnapshot(
                    symbolKind: .function,
                    roles: [.reference],
                    locationLine: 10,
                    locationColumn: 5,
                    symbolUSR: "usr.func.main",
                    symbolName: "main()",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines: [String] = []
        let allModuleNames: Set<String> = []
        let sut = IndexStoreImportExtractor()

        // When
        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        // Then
        #expect(result.isEmpty)
    }

    @Test("imports given invalid fileLines returns empty")
    func test_importsGivenInvalidLinesReturnsEmpty() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines: [String] = ["invalid lines"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result.isEmpty)
    }

    @Test("imports returns imported module when occurrence points at testable import line")
    func test_imports_ReturnsImportedModuleWhenOccurrencePointsAtTestableImportLine() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["@testable import ModuleA"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result == ["ModuleA"])
    }

    @Test("imports returns empty when occurrence points at invalid import line")
    func test_imports_ReturnsEmptyWhenOccurrencePointsAtInvalidImportLine() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["import  ."]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result.isEmpty)
    }

    @Test("imports returns empty when occurrence points at exported import line")
    func test_imports_ReturnsEmptyWhenOccurrencePointsAtExportedImportLine() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["@exported import ModuleC"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result.isEmpty)
    }

    @Test("imports returns imported module when occurrence points at import line")
    func test_imports_ReturnsImportedModuleWhenOccurrencePointsAtImportLine() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["import ModuleA"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result == ["ModuleA"])
    }

    @Test("imports ignores modules not included in allModuleNames")
    func test_imports_IgnoresModulesNotIncludedInAllModuleNames() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.unknown",
                    symbolName: "UnknownModule",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["import UnknownModule"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result.isEmpty)
    }

    @Test("imports ignores modules included in ignoredModules")
    func test_imports_IgnoresModulesIncludedInIgnoredModules() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["import ModuleA"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: ["ModuleA"]
        )

        #expect(result.isEmpty)
    }

    @Test("imports ignores @ignore-import annotated import lines")
    func test_imports_IgnoresIgnoreAnnotatedImportLines() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 1,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["import ModuleA // @ignore-import"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result.isEmpty)
    }

    @Test("imports returns empty when occurrence line is out of bounds")
    func test_imports_ReturnsEmptyWhenOccurrenceLineIsOutOfBounds() {
        let mainFile = "/app/App.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: [
                OccurrenceSnapshot(
                    symbolKind: .module,
                    roles: [.reference],
                    locationLine: 2,
                    locationColumn: 1,
                    symbolUSR: "usr.import.modulea",
                    symbolName: "ModuleA",
                    relatedSymbols: []
                )
            ]
        ]
        let fileLines = ["import ModuleA"]
        let allModuleNames: Set<String> = ["App", "ModuleA"]

        let sut = IndexStoreImportExtractor()

        let result = sut.imports(
            inMainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines,
            allModuleNames: allModuleNames,
            ignoredModules: []
        )

        #expect(result.isEmpty)
    }
}
