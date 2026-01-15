import Foundation

protocol UnnecessaryTestableAnalyzing {
    func analyze(store: some IndexStoreProviding, indexStorePath: String) async throws -> [String: Set<String>]
}
