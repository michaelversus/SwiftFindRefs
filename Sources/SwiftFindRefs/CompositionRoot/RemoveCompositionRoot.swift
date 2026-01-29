import Foundation
@preconcurrency import IndexStore

struct RemoveCompositionRoot {
    let projectName: String?
    let dataStorePath: String?
    let excludeCompilationConditionals: Bool
    let print: (String) -> Void
    let vPrint: (String) -> Void
    let fileSystem: FileSystemProvider
    let derivedDataLocator: DerivedDataLocatorProtocol
    let removerFactory: (String) -> UnnecessaryTestableRemoving

    func run() async throws {
        var pathToDataStore: String
        if let dataStorePath {
            guard fileSystem.fileExists(atPath: dataStorePath) else { throw DataStorePathValidationError.invalidPath(dataStorePath) }
            pathToDataStore = dataStorePath
        } else {
            let derivedDataPaths = try derivedDataLocator.locateDerivedData(
              projectName: projectName
            )
            pathToDataStore = derivedDataPaths.dataStoreURL.path()
            vPrint("Discovering DataStore path based on projectName: \(String(describing: projectName))")
        }
        vPrint("Using DataStore path: \(pathToDataStore)")
        
        let remover = removerFactory(pathToDataStore)
        let updatedFiles = try await remover.run()
        print("✅ Updated \(updatedFiles.count) files")
        vPrint("Updated files:")
        updatedFiles.sorted().forEach { vPrint($0) }
    }
}
