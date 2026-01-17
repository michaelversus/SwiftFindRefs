import ArgumentParser
import Foundation

extension SwiftFindRefs {
    struct Search: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Search for symbol references.")

        @OptionGroup
        var common: CommonOptions

        @Option(name: [.short, .customLong("symbolName")], help: "The symbol name to find references for")
        var name: String

        @Option(name: [.short, .customLong("symbolType")], help: "The symbol type (e.g., function, variable, class)")
        var type: String?

        func run() async throws {
            let fileSystem = FileSystem(fileManager: FileManager.default)
            let derivedDataLocator = DerivedDataLocator(fileSystem: fileSystem)
            let compositionRoot = SearchCompositionRoot(
                projectName: common.projectName,
                derivedDataPath: common.derivedDataPath,
                symbolName: name,
                symbolType: type,
                print: { print($0) },
                vPrint: { if common.verbose { print($0) } },
                fileSystem: fileSystem,
                derivedDataLocator: derivedDataLocator
            )
            try await compositionRoot.run()
        }
    }
}
