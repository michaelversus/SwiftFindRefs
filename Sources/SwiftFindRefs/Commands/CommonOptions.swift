import ArgumentParser

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
}
