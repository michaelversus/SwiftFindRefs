import Foundation
@preconcurrency import IndexStore

struct RemoveCompositionRoot {
    let projectName: String?
    let derivedDataPath: String?
    let excludeCompilationConditionals: Bool
    let print: (String) -> Void
    let vPrint: (String) -> Void
    let fileSystem: FileSystemProvider
    let derivedDataLocator: DerivedDataLocatorProtocol
    let removerFactory: (String) -> UnnecessaryTestableRemoving

    func run() async throws {
        let derivedDataPaths = try derivedDataLocator.locateDerivedData(
            projectName: projectName,
            derivedDataPath: derivedDataPath
        )
        vPrint("DerivedData path: \(derivedDataPaths.derivedDataURL.path)")
        vPrint("IndexStoreDB path: \(derivedDataPaths.indexStoreDBURL.path)")
        let indexStorePath = derivedDataPaths.indexStoreDBURL.deletingLastPathComponent().path
        let remover = removerFactory(indexStorePath)
        let updatedFiles = try await remover.run()
        print("✅ Updated \(updatedFiles.count) files")
        vPrint("Updated files:")
        updatedFiles.sorted().forEach { vPrint($0) }
    }
}
