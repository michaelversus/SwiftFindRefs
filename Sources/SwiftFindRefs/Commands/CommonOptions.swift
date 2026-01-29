import ArgumentParser

extension SwiftFindRefs {
    /// Common CLI parameters shared by commands that interact with the Xcode derived data directories.
    struct CommonOptions: ParsableArguments {
        /// Optional Xcode project name used to locate the corresponding derived data directory automatically.
        //@Option(name: [.short, .customLong("projectName")], help: "The name of the Xcode project to help CLI find the Derived Data Index Store Path")
        var projectName: String? = "Kaizen"

        /// Optional explicit derived data path for scenarios where automatic discovery is insufficient.
        @Option(name: [.short, .customLong("derivedDataPath")], help: "The Derived Data path where Xcode stores build data")
        var derivedDataPath: String?

        /// Flag to enable verbose output for diagnostic purposes.
        @Flag(name: .shortAndLong, help: "Enable verbose output.")
        var verbose: Bool = false

        /// The path to the `.swift-find-refs.json` configuration file.
        /// If omitted, the tool attempts to locate a configuration in the current directory.
        @Option(name: [.short, .customLong("config")], help: "The path of `.swift-find-refs.json`.")
        var configurationPath: String?

        /// The root path of the project to analyze.
        /// Defaults to the current working directory when not provided.
//        @Option(
//            name: .shortAndLong,
//            help: "The rootPath of your project. Defaults to current directory."
//        )
        var rootPath: String? = "/Users/m.karagiorgos/iosnative1"

        /// Validates that at least one location hint (project name or derived data path) is provided.
        func validate() throws {
            guard projectName?.isEmpty == false || derivedDataPath?.isEmpty == false else {
                throw ValidationError("Provide either --projectName or --derivedDataPath.")
            }
        }
    }
}
