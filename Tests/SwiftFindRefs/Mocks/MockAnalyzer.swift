@testable import SwiftFindRefs

final class MockAnalyzer: UnnecessaryAnalyzing {
    private let result: [String: Set<String>]
    private(set) var calls = 0

    init(result: [String: Set<String>]) {
        self.result = result
    }

    func analyze() async throws -> [String: Set<String>] {
        calls += 1
        return result
    }
}
