import ArgumentParser
import Foundation
@preconcurrency import IndexStore

extension SwiftFindRefs {
    /// Command that removes unnecessary imports discovered via IndexStore analysis.
    struct RemoveUI: AsyncParsableCommand {
        /// CLI metadata that declares the command name, description, and alias set.
        static let configuration = CommandConfiguration(
            commandName: "removeUnnecessaryImports",
            abstract: "Remove unnecessary imports.",
            aliases: ["rmUI"]
        )

        /// Shared options that provide derived data context and verbosity settings.
        @OptionGroup
        var common: CommonOptions

        /// Toggles exclusion of imports inside conditional compilation directives.
        @Flag(
            name: .customLong("excludeCompilationConditionals"),
            help: "Exclude imports inside #if/#elseif/#else/#endif blocks."
        )
        var excludeCompilationConditionals: Bool = false

        /// Builds the removal pipeline using the resolved IndexStore location and executes it.
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
                    UnnecessaryRemover(
                        indexStorePath: indexStorePath,
                        print: { print($0) },
                        storeFactory: { try IndexStore(path: indexStorePath) },
                        analyzer: UnnecessaryTestableAnalyzer(
                            fileSystem: fileSystem,
                            extractor: ImportExtractor(
                                fileSystem: fileSystem,
                                excludeCompilationConditionals: excludeCompilationConditionals,
                                prefix: .regularImport
                            ),
                            collector: IndexStoreCollector.self
                        ),
                        rewriter: UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { print($0) }),
                        mode: .imports
                    )
                }
            )
            try await compositionRoot.run()
        }
    }
}
