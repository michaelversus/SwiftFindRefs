@testable import SwiftFindRefs

final class MockRewriter: UnnecessaryRewriting {
    private let result: [String]
    var actions: [Action] = []
    enum Action: Equatable {
        case rewriteFiles(removalsByFile: [String: Set<String>])
    }

    init(result: [String]) {
        self.result = result
    }

    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String] {
        actions.append(.rewriteFiles(removalsByFile: removalsByFile))
        return result
    }
}
