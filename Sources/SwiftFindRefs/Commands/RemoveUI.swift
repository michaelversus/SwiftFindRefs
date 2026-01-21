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
            let vPrint = { if common.verbose { print($0) } }
            let fileSystem = FileSystem(fileManager: FileManager.default)
            let derivedDataLocator = DerivedDataLocator(fileSystem: fileSystem)
            let derivedDataPaths = try derivedDataLocator.locateDerivedData(
                projectName: common.projectName,
                derivedDataPath: common.derivedDataPath
            )
            vPrint("DerivedData path: \(derivedDataPaths.derivedDataURL.path)")
            vPrint("IndexStoreDB path: \(derivedDataPaths.indexStoreDBURL.path)")
            let indexStorePath = derivedDataPaths.indexStoreDBURL.deletingLastPathComponent().path
            let store = try IndexStore(path: indexStorePath)
            let compositionRoot = RemoveCompositionRoot(
                rootPath: common.rootPath,
                print: { print($0) },
                vPrint: { if common.verbose { print($0) } },
                fileSystem: fileSystem,
                removerFactory: { configuration in
                    UnnecessaryRemover(
                        print: { print($0) },
                        analyzer: UnnecessaryImportsAnalyzer(
                            fileSystem: fileSystem,
                            extractor: ImportExtractor(
                                fileSystem: fileSystem,
                                excludeCompilationConditionals: excludeCompilationConditionals,
                                ignoredModules: configuration.unusedImports.ignoredModules,
                                prefix: .regularImport
                            ),
                            collector: IndexStoreCollector(
                                store: store,
                                indexStorePath: indexStorePath
                            ),
                            indexStoreImportExtractor: IndexStoreImportExtractor()
                        ),
                        rewriter: UnnecessaryImportsRewriter(
                            fileSystem: fileSystem,
                            print: { print($0) }
                        ),
                        mode: .imports
                    )
                }
            )
            try await compositionRoot.run()
        }
    }
}
