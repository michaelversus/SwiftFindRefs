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
            // Compute root path before creating compositionRoot
            let resolvedRootPath = common.rootPath ?? fileSystem.currentDirectoryPath
            let rootPath = resolvedRootPath.hasSuffix("/") ? resolvedRootPath : resolvedRootPath + "/"
            let compositionRoot = RemoveCompositionRoot(
                rootPath: common.rootPath,
                print: { print($0) },
                vPrint: vPrint,
                fileSystem: fileSystem,
                removerFactory: { configuration in
                    let ignoredModules: [String] = configuration.unusedImports?.ignoredModules ?? []
                    let excludedDirs: [String]? = configuration.unusedImports?.excludedDirectories
                    return UnnecessaryRemover(
                        print: { print($0) },
                        analyzer: UnnecessaryImportsAnalyzer(
                            fileSystem: fileSystem,
                            collector: IndexStoreCollector(
                                store: store,
                                indexStorePath: indexStorePath
                            ),
                            indexStoreImportExtractor: IndexStoreImportExtractor(),
                            ignoredModules: Set(ignoredModules),
                            excludedDirectories: excludedDirs,
                            rootPath: rootPath,
                            vPrint: vPrint
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
