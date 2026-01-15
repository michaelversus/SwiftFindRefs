import ArgumentParser
import Foundation
@preconcurrency import IndexStore

@main
struct SwiftFindRefs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "CLI that helps you interact with Xcode's IndexStoreDB.",
        subcommands: [Search.self, Remove.self],
        defaultSubcommand: Search.self
    )
}

extension SwiftFindRefs {
    struct CommonOptions: ParsableArguments {
        @Option(name: [.short, .customLong("projectName")], help: "The name of the Xcode project to help CLI find the Derived Data Index Store Path")
        var projectName: String?

        @Option(name: [.short, .customLong("derivedDataPath")], help: "The Derived Data path where Xcode stores build data")
        var derivedDataPath: String?

        /// Flag to enable verbose output for diagnostic purposes.
        @Flag(name: .shortAndLong, help: "Enable verbose output.")
        var verbose: Bool = false

        func validate() throws {
            guard projectName?.isEmpty == false || derivedDataPath?.isEmpty == false else {
                throw ValidationError("Provide either --projectName or --derivedDataPath.")
            }
        }
    }

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

    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "removeUnnecessaryTestableImports",
            abstract: "Remove unnecessary @testable imports.",
            aliases: ["rmUTI"]
        )

        @OptionGroup
        var common: CommonOptions

        @Flag(name: .customLong("excludeCompilationConditionals"),
              help: "Exclude @testable imports inside #if/#elseif/#else/#endif blocks.")
        var excludeCompilationConditionals: Bool = false

        func run() async throws {
            let fileSystem = FileSystem(fileManager: FileManager.default)
            let derivedDataLocator = DerivedDataLocator(fileSystem: fileSystem)
            let compositionRoot = RemoveCompositionRoot(
                projectName: common.projectName,
                derivedDataPath: common.derivedDataPath,
                excludeCompilationConditionals: excludeCompilationConditionals,
                print: { print($0) },
                vPrint: { if common.verbose { print($0) } },
                fileSystem: fileSystem,
                derivedDataLocator: derivedDataLocator,
                removerFactory: { indexStorePath in
                    UnnecessaryTestableRemover(
                        indexStorePath: indexStorePath,
                        print: { print($0) },
                        storeFactory: { try IndexStore(path: indexStorePath) },
                        analyzer: UnnecessaryTestableAnalyzer(
                            fileSystem: fileSystem,
                            extractor: TestableImportExtractor(
                                fileSystem: fileSystem,
                                excludeCompilationConditionals: excludeCompilationConditionals
                            )
                        ),
                        rewriter: UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { print($0) })
                    )
                }
            )
            try await compositionRoot.run()
        }
    }
}
