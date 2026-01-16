import Foundation

protocol UnnecessaryTestableRewriting {
    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String]
}
