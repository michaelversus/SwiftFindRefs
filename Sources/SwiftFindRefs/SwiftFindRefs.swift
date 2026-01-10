import ArgumentParser
import Foundation

@main
struct SwiftFindRefs: ParsableCommand {
    //@Option(name: [.short, .customLong("projectName")], help: "The name of the Xcode project to help CLI find the Derived Data Index Store Path")
    var projectName: String? = "Kaizen"

    //@Option(name: [.short, .customLong("derivedDataPath")], help: "The Derived Data path where Xcode stores build data")
    var derivedDataPath: String?

//    @Option(name: [.short, .customLong("symbolName")], help: "The symbol name to find references for")
    var symbolName: String = "Selection"

    //@Option(name: [.short, .customLong("symbolType")], help: "The symbol type (e.g., function, variable, class)")
    var symbolType: String? = "class"

    /// Flag to enable verbose output for diagnostic purposes.
    //@Option(name: .shortAndLong, help: "Flag to enable verbose output.")
    var verbose: Bool = true

    func run() throws {
        let fileSystem = FileSystem(
            fileManager: FileManager.default
        )
        let derivedDataLocator = DerivedDataLocator(fileSystem: fileSystem)
        let compositionRoot = CompositionRoot(
            projectName: projectName,
            derivedDataPath: derivedDataPath,
            symbolName: symbolName,
            symbolType: symbolType,
            print: { print($0) },
            vPrint: { if verbose { print($0) } },
            fileSystem: fileSystem,
            derivedDataLocator: derivedDataLocator
        )
        try compositionRoot.run()
    }
}
