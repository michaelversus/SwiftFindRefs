import Foundation

/// Composition root that wires the dependencies required to perform a symbol reference search.
struct SearchCompositionRoot {
    let symbolName: String
    let symbolType: String?
    let print: (String) -> Void
    let indexStoreFinder: any IndexStoreFinding

    /// Resolves derived data paths, configures the finder, and prints the located references.
    func run() async throws {
        print("🔍 Searching for references to symbol '\(symbolName)' of type '\(symbolType ?? "any")'")
        let references = try await indexStoreFinder.fileReferences(
            of: symbolName,
            symbolType: symbolType
        )
        print("✅ Found \(references.count) references:\n\(references.joined(separator: "\n"))")
    }
}
