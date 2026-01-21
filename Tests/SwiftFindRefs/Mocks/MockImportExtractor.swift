@testable import SwiftFindRefs

struct MockImportExtractor: ImportExtracting, Sendable {
    let resultsByFile: [String: Set<String>]

    func imports(inFile path: String) async throws -> Set<String> {
        resultsByFile[path] ?? []
    }
}
