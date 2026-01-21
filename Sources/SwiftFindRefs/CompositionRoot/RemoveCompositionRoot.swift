import Foundation
@preconcurrency import IndexStore

/// Composition root responsible for constructing the removal pipeline with derived data context.
struct RemoveCompositionRoot {
    let rootPath: String?
    let print: (String) -> Void
    let vPrint: (String) -> Void
    let fileSystem: FileSystemProvider
    let removerFactory: (Configuration) -> UnnecessaryRemoving

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
        let configurationLoader = ConfigurationLoader(fileSystem: fileSystem, print: print)
        let configuration = try configurationLoader.loadConfiguration(
            at: nil,
            root: root
        )
        let remover = removerFactory(configuration)
        let updatedFiles = try await remover.run()
        print("✅ Updated \(updatedFiles.count) files")
        vPrint("Updated files:")
        updatedFiles.sorted().forEach { vPrint($0) }
    }
}
