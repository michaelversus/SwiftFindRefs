protocol TestableImportExtracting {
    func testableImports(inFile path: String) async throws -> Set<String>
}
