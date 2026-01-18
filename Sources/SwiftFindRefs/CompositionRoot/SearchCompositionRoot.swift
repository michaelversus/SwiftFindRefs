import Foundation

/// Composition root that wires the dependencies required to perform a symbol reference search.
struct SearchCompositionRoot {
    let projectName: String?
    let derivedDataPath: String?
    let symbolName: String
    let symbolType: String?
    let print: (String) -> Void
    let vPrint: (String) -> Void
    let fileSystem: FileSystemProvider
    let derivedDataLocator: DerivedDataLocatorProtocol

    /// Resolves derived data paths, configures the finder, and prints the located references.
    func run() async throws {
        let derivedDataPaths = try derivedDataLocator.locateDerivedData(
            projectName: projectName,
            derivedDataPath: derivedDataPath
        )
        vPrint("DerivedData path: \(derivedDataPaths.derivedDataURL.path)")
        vPrint("IndexStoreDB path: \(derivedDataPaths.indexStoreDBURL.path)")
        let indexStorePath = derivedDataPaths.indexStoreDBURL.deletingLastPathComponent().path
        let indexStoreFinder = IndexStoreFinder(indexStorePath: indexStorePath)
        print("🔍 Searching for references to symbol '\(symbolName)' of type '\(symbolType ?? "any")'")
        let references = try await indexStoreFinder.fileReferences(of: symbolName, symbolType: symbolType)
        print("✅ Found \(references.count) references:\n\(references.joined(separator: "\n"))")
    }
}
