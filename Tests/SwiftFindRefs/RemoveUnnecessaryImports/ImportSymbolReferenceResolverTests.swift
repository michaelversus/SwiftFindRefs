import Foundation
import IndexStore
import Testing
@testable import SwiftFindRefs

@Suite("ImportSymbolReferenceResolver Tests")
struct ImportSymbolReferenceResolverTests {

    // MARK: - Tests

    @Test("test getReferenceUSRs GivenNoOccurrencesForMainFile_returnsEmptySets")
    func test_getReferenceUSRs_GivenNoOccurrencesForMainFile_returnsEmptySets() {
        // Given
        let mainFile = "/main.swift"
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [:]

        // When
        let result = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile
        )

        // Then
        #expect(result.0.isEmpty)
        #expect(result.1.isEmpty)
        #expect(result.2.isEmpty)
        #expect(result.3.isEmpty)
    }

    @Test("test getReferenceUSRs GivenExtensionOccurrence_collectsUSRAndNameEvenWithoutReferenceRole")
    func test_getReferenceUSRs_GivenExtensionOccurrence_collectsUSRAndNameEvenWithoutReferenceRole() {
        // Given
        let mainFile = "/main.swift"
        let extensionOccurrence = OccurrenceSnapshot(
            symbolKind: .extension,
            roles: [],
            locationLine: 1,
            locationColumn: 1,
            symbolUSR: "usr.extension",
            symbolName: "MyType",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [extensionOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile
        )

        // Then
        #expect(usrs == ["usr.extension"])
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames == ["MyType"])
        #expect(typealiases.isEmpty)
    }

    @Test("test getReferenceUSRs GivenReferenceOccurrence_collectsUSRAndName")
    func test_getReferenceUSRs_GivenReferenceOccurrence_collectsUSRAndName() {
        // Given
        let mainFile = "/main.swift"
        let referenceOccurrence = OccurrenceSnapshot(
            symbolKind: .class,
            roles: [.reference],
            locationLine: 1,
            locationColumn: 1,
            symbolUSR: "usr.foo",
            symbolName: "Foo",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [referenceOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile
        )

        // Then
        #expect(usrs == ["usr.foo"])
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames == ["Foo"])
        #expect(typealiases.isEmpty)
    }

    @Test("test getReferenceUSRs GivenNonReferenceNonExtensionOccurrence_ignoresOccurrence")
    func test_getReferenceUSRs_GivenNonReferenceNonExtensionOccurrence_ignoresOccurrence() {
        // Given
        let mainFile = "/main.swift"
        let irrelevantOccurrence = OccurrenceSnapshot(
            symbolKind: .class,
            roles: [.definition],
            locationLine: 1,
            locationColumn: 1,
            symbolUSR: "usr.foo",
            symbolName: "Foo",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [irrelevantOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile
        )

        // Then
        #expect(usrs.isEmpty)
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames.isEmpty)
        #expect(typealiases.isEmpty)
    }

    @Test("test getReferenceUSRs GivenOverrideOrBaseReference_collectsOverrideUSR")
    func test_getReferenceUSRs_GivenOverrideOrBaseReference_collectsOverrideUSR() {
        // Given
        let mainFile = "/main.swift"
        let overrideOccurrence = OccurrenceSnapshot(
            symbolKind: .instanceMethod,
            roles: [.reference, .overrideOf],
            locationLine: 1,
            locationColumn: 1,
            symbolUSR: "usr.override",
            symbolName: "doWork()",
            relatedSymbols: []
        )
        let baseOccurrence = OccurrenceSnapshot(
            symbolKind: .instanceMethod,
            roles: [.reference, .baseOf],
            locationLine: 2,
            locationColumn: 1,
            symbolUSR: "usr.base",
            symbolName: "doWork()",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [overrideOccurrence, baseOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile
        )

        // Then
        #expect(usrs == ["usr.override", "usr.base"])
        #expect(overrideUSRs == ["usr.override", "usr.base"])
        #expect(referencedNames == ["doWork()"])
        #expect(typealiases.isEmpty)
    }

    @Test("test getReferenceUSRs GivenExtensionAndFileLinesWithDifferentIdentifier_collectsTypealias")
    func test_getReferenceUSRs_GivenExtensionAndFileLinesWithDifferentIdentifier_collectsTypealias() {
        // Given
        let mainFile = "/main.swift"
        let fileLines = [
            "extension [Int] {}"
        ]
        let extensionOccurrence = OccurrenceSnapshot(
            symbolKind: .extension,
            roles: [],
            locationLine: 1,
            locationColumn: 11,
            symbolUSR: "usr.extension",
            symbolName: "Array",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [extensionOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines
        )

        // Then
        #expect(usrs == ["usr.extension"])
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames == ["Array"])
        #expect(typealiases == ["Int"])
    }

    @Test("test getReferenceUSRs GivenExtensionAndInvalidLineOrColumn_doesNotCollectTypealias")
    func test_getReferenceUSRs_GivenExtensionAndInvalidLineOrColumn_doesNotCollectTypealias() {
        // Given
        let mainFile = "/main.swift"
        let fileLines = [
            "extension [Int] {}"
        ]
        let invalidLineOccurrence = OccurrenceSnapshot(
            symbolKind: .extension,
            roles: [],
            locationLine: 2,
            locationColumn: 11,
            symbolUSR: "usr.invalidLine",
            symbolName: "Array",
            relatedSymbols: []
        )
        let invalidColumnOccurrence = OccurrenceSnapshot(
            symbolKind: .extension,
            roles: [],
            locationLine: 1,
            locationColumn: 0,
            symbolUSR: "usr.invalidColumn",
            symbolName: "Array",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [invalidLineOccurrence, invalidColumnOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines
        )

        // Then
        #expect(usrs == ["usr.invalidLine", "usr.invalidColumn"])
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames == ["Array"])
        #expect(typealiases.isEmpty)
    }

    @Test("test getReferenceUSRs GivenFileLinesWithStaticPropertyAccess_collectsTypeName")
    func test_getReferenceUSRs_GivenFileLinesWithStaticPropertyAccess_collectsTypeName() {
        // Given
        let mainFile = "/main.swift"
        let fileLines = [
            "let value = Settings.shared",
            "let other = TypeName.staticProperty",
            "let ignored = settings.shared"
        ]
        let occurrencesByFile: [String: [OccurrenceSnapshot]] = [
            mainFile: []
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines
        )

        // Then
        #expect(usrs.isEmpty)
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames == ["Settings", "TypeName"])
        #expect(typealiases.isEmpty)
    }

    @Test("test getReferenceUSRs GivenExtensionWithNoIdentifierInLine_doesNotCollectTypealias")
    func test_getReferenceUSRs_GivenExtensionWithNoIdentifierInLine_doesNotCollectTypealias() {
        // Given
        // This is designed to hit:
        // `guard let match = try? identifierRegex.firstMatch(in: String(lineFromColumn)) else { continue }`
        //
        // Important: `identifierRegex` is not anchored, so the only way to ensure `firstMatch` returns nil
        // is to provide a substring with *no* identifier characters at all.
        let mainFile = "/main.swift"
        let line = "[]{}()"
        let fileLines = [line]

        let extensionOccurrence = OccurrenceSnapshot(
            symbolKind: .extension,
            roles: [],
            locationLine: 1,
            locationColumn: 1,
            symbolUSR: "usr.noIdentifierMatch",
            symbolName: "Array",
            relatedSymbols: []
        )
        let occurrencesByFile = [
            mainFile: [extensionOccurrence]
        ]

        // When
        let (usrs, overrideUSRs, referencedNames, typealiases) = ImportSymbolReferenceResolver.getReferenceUSRs(
            mainFile: mainFile,
            occurrencesByFile: occurrencesByFile,
            fileLines: fileLines
        )

        // Then
        #expect(usrs == ["usr.noIdentifierMatch"])
        #expect(overrideUSRs.isEmpty)
        #expect(referencedNames == ["Array"])
        #expect(typealiases.isEmpty)
    }
}
