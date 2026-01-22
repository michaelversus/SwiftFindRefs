struct Configuration: Decodable, Equatable {
    let unusedImports: UnusedImportsConfiguration?
    let unusedTestableImports: UnusedTestableImportsConfiguration?
}

struct UnusedImportsConfiguration: Decodable, Equatable {
    let ignoredModules: [String]?
    let excludedDirectories: [String]?
}

struct UnusedTestableImportsConfiguration: Decodable, Equatable {
    let excludedDirectories: [String]?
}
