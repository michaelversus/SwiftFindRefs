protocol ImportExtracting {
    func imports(inFile path: String) async throws -> Set<String>
}
