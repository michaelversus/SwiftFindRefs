@testable import SwiftFindRefs

final class MockRemover: UnnecessaryRemoving {
    private let result: [String]
    private(set) var calls: Int = 0

    init(result: [String]) {
        self.result = result
    }

    func run() async throws -> [String] {
        calls += 1
        return result
    }
}
