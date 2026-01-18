import Foundation

protocol UnnecessaryAnalyzing {
    func analyze(store: some IndexStoreProviding, indexStorePath: String) async throws -> [String: Set<String>]
}
