import ArgumentParser
import Foundation
@preconcurrency import IndexStore

extension SwiftFindRefs {
    struct RemoveUI: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "removeUnnecessaryImports",
            abstract: "Remove unnecessary imports.",
            aliases: ["rmUI"]
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
                    UnnecessaryRemover(
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
                        rewriter: UnnecessaryTestableRewriter(fileSystem: fileSystem, print: { print($0) }),
                        mode: .imports
                    )
                }
            )
            try await compositionRoot.run()
        }
    }
}
