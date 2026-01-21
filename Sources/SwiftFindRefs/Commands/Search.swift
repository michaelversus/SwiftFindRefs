import ArgumentParser
import Foundation


extension SwiftFindRefs {
    /// Command that finds symbol references by querying IndexStore records.
    struct Search: AsyncParsableCommand {
        /// CLI metadata summarizing the search command and its purpose.
        static let configuration = CommandConfiguration(abstract: "Search for symbol references.")

        /// Shared options that provide derived data lookup hints and verbosity.
        @OptionGroup
        var common: CommonOptions

        /// Symbol name to locate inside the IndexStore.
        @Option(name: [.short, .customLong("symbolName")], help: "The symbol name to find references for")
        var name: String

        /// Optional symbol kind (function, variable, class, etc.) to narrow the results.
        @Option(name: [.short, .customLong("symbolType")], help: "The symbol type (e.g., function, variable, class)")
        var type: String?

        /// Constructs the search pipeline and executes it against the resolved derived data path.
        func run() async throws {
            let fileSystem = FileSystem(fileManager: FileManager.default)
            let derivedDataLocator = DerivedDataLocator(fileSystem: fileSystem)
            let derivedDataPaths = try derivedDataLocator.locateDerivedData(
                projectName: common.projectName,
                derivedDataPath: common.derivedDataPath
            )
            let vPrint = { if common.verbose { print($0) } }
            vPrint("DerivedData path: \(derivedDataPaths.derivedDataURL.path)")
            vPrint("IndexStoreDB path: \(derivedDataPaths.indexStoreDBURL.path)")
            let indexStorePath = derivedDataPaths.indexStoreDBURL.deletingLastPathComponent().path
            let compositionRoot = SearchCompositionRoot(
                symbolName: name,
                symbolType: type,
                print: { print($0) },
                indexStoreFinder: IndexStoreFinder(indexStorePath: indexStorePath)
            )
            try await compositionRoot.run()
        }
    }
}
