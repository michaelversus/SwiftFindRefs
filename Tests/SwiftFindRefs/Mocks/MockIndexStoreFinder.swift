@testable import SwiftFindRefs

struct MockIndexStoreFinder: IndexStoreFinding {
    let references: [String]

    func fileReferences(
        of symbolName: String,
        symbolType: String?
    ) async throws -> [String] {
        references
    }
}
