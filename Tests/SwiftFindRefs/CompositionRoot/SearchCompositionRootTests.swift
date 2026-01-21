import Testing
@testable import SwiftFindRefs

@Suite("SearchCompositionRoot Tests")
struct SearchCompositionRootTests {

    // MARK: - Tests

    @Test("test run prints found references message")
    func test_run_printsFoundReferencesMessage() async throws {
        // Given
        let references = ["/mock/FileA.swift", "/mock/FileB.swift"]
        let indexStoreFinder = MockIndexStoreFinder(references: references)
        var standardMessages: [String] = []

        let sut = makeSearchSUT(
            symbolName: "MySymbol",
            symbolType: "class",
            indexStoreFinder: indexStoreFinder,
            print: { standardMessages.append($0) }
        )

        // When
        try await sut.run()

        // Then
        let foundMessage = try #require(standardMessages.first { $0.contains("✅ Found") })
        #expect(foundMessage.contains("✅ Found 2 references:"))
        #expect(foundMessage.contains(references.joined(separator: "\n")))
    }

    // MARK: - Helpers

    private func makeSearchSUT(
        symbolName: String = "MySymbol",
        symbolType: String? = "class",
        indexStoreFinder: some IndexStoreFinding,
        print: @escaping (String) -> Void = { _ in }
    ) -> SearchCompositionRoot {
        return SearchCompositionRoot(
            symbolName: symbolName,
            symbolType: symbolType,
            print: print,
            indexStoreFinder: indexStoreFinder
        )
    }
}
