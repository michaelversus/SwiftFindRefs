import Foundation

protocol UnnecessaryRewriting {
    func rewriteFiles(_ removalsByFile: [String: Set<String>]) async throws -> [String]
}
