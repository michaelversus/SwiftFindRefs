import Foundation

struct SearchCompositionRoot {
    let projectName: String?
    let dataStorePath: String?
    let symbolName: String
    let symbolType: String?
    let print: (String) -> Void
    let vPrint: (String) -> Void
    let fileSystem: FileSystemProvider
    let derivedDataLocator: DerivedDataLocatorProtocol

    func run() async throws {
        var pathToDataStore: String
        if let dataStorePath {
            guard fileSystem.fileExists(atPath: dataStorePath) else { throw DataStorePathValidationError.invalidPath(dataStorePath) }
            pathToDataStore = dataStorePath
            
        } else {
            let derivedDataPaths = try derivedDataLocator.locateDerivedData(projectName: projectName)
            pathToDataStore = derivedDataPaths.dataStoreURL.path()
            vPrint("Discovering DataStore path based on projectName: \(String(describing: projectName))")
        }
        vPrint("Using DataStore path: \(pathToDataStore)")
        
        let indexStoreFinder = IndexStoreFinder(indexStorePath: pathToDataStore)
        print("🔍 Searching for references to symbol '\(symbolName)' of type '\(symbolType ?? "any")'")
        let references = try await indexStoreFinder.fileReferences(of: symbolName, symbolType: symbolType)
        print("✅ Found \(references.count) references:\n\(references.joined(separator: "\n"))")
    }
}
