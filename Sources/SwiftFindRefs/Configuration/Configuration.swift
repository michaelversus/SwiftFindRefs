struct Configuration: Decodable, Equatable {
    let unusedImports: UnusedImportsConfiguration
}

struct UnusedImportsConfiguration: Decodable, Equatable {
    let ignoredModules: [String]
}
