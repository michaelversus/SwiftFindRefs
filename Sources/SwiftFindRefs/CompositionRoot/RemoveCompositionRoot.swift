import Foundation
@preconcurrency import IndexStore

/// Composition root responsible for constructing the removal pipeline with derived data context.
struct RemoveCompositionRoot {
    let projectName: String?
    let derivedDataPath: String?
    let rootPath: String?
    let excludeCompilationConditionals: Bool
    let print: (String) -> Void
    let vPrint: (String) -> Void
    let fileSystem: FileSystemProvider
    let derivedDataLocator: DerivedDataLocatorProtocol
    let removerFactory: (String, Configuration) -> UnnecessaryRemoving

    /// Resolved root path guaranteed to end with a trailing slash for consistent path concatenation.
    var root: String {
        let rootPath = rootPath ?? fileSystem.currentDirectoryPath
        if rootPath.hasSuffix("/") {
            return rootPath
        } else {
            return rootPath + "/"
        }
    }

    /// Resolves the derived data paths, builds the remover, and reports updated files.
    func run() async throws {
        let derivedDataPaths = try derivedDataLocator.locateDerivedData(
            projectName: projectName,
            derivedDataPath: derivedDataPath
        )
        vPrint("DerivedData path: \(derivedDataPaths.derivedDataURL.path)")
        vPrint("IndexStoreDB path: \(derivedDataPaths.indexStoreDBURL.path)")
        let indexStorePath = derivedDataPaths.indexStoreDBURL.deletingLastPathComponent().path
        let configurationLoader = ConfigurationLoader(fileSystem: fileSystem, print: print)
        let configuration = try configurationLoader.loadConfiguration(
            at: nil,
            root: root
        )
        let remover = removerFactory(indexStorePath, configuration)
        let updatedFiles = try await remover.run()
        print("✅ Updated \(updatedFiles.count) files")
        vPrint("Updated files:")
        updatedFiles.sorted().forEach { vPrint($0) }
    }
}
