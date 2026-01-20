import ArgumentParser
import Foundation
@preconcurrency import IndexStore

extension SwiftFindRefs {
    /// Command that removes unnecessary @testable imports detected via IndexStore analysis.
    struct RemoveUTI: AsyncParsableCommand {
        /// CLI metadata declaring the command identifier, summary, and aliases.
        static let configuration = CommandConfiguration(
            commandName: "removeUnnecessaryTestableImports",
            abstract: "Remove unnecessary @testable imports.",
            aliases: ["rmUTI"]
        )

        /// Common CLI options supplying derived data discovery hints and verbosity.
        @OptionGroup
        var common: CommonOptions

        /// Flag that excludes @testable imports found within conditional compilation regions.
        @Flag(name: .customLong("excludeCompilationConditionals"),
              help: "Exclude @testable imports inside #if/#elseif/#else/#endif blocks.")
        var excludeCompilationConditionals: Bool = false

        /// Constructs the removal pipeline for the resolved IndexStore path and runs it.
        func run() async throws {
            let fileSystem = FileSystem(fileManager: FileManager.default)
            let derivedDataLocator = DerivedDataLocator(fileSystem: fileSystem)
            let compositionRoot = RemoveCompositionRoot(
                projectName: common.projectName,
                derivedDataPath: common.derivedDataPath,
                rootPath: common.rootPath,
                excludeCompilationConditionals: excludeCompilationConditionals,
                print: { print($0) },
                vPrint: { if common.verbose { print($0) } },
                fileSystem: fileSystem,
                derivedDataLocator: derivedDataLocator,
                removerFactory: { indexStorePath, _ in
                    UnnecessaryRemover(
                        indexStorePath: indexStorePath,
                        print: { print($0) },
                        storeFactory: { try IndexStore(path: indexStorePath) },
                        analyzer: UnnecessaryTestableAnalyzer(
                            fileSystem: fileSystem,
                            extractor: ImportExtractor(
                                fileSystem: fileSystem,
                                excludeCompilationConditionals: excludeCompilationConditionals,
                                ignoredModules: [],
                                prefix: .testableImport
                            ),
                            collector: IndexStoreCollector.self
                        ),
                        rewriter: UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { print($0) }),
                        mode: .testableImports
                    )
                }
            )
            try await compositionRoot.run()
        }
    }
}
