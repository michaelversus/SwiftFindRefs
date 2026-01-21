/// Abstraction used to query an IndexStore for symbol references.
///
/// This exists to keep `SearchCompositionRoot` unit-testable without accessing a real IndexStore database.
protocol IndexStoreFinding {
    func fileReferences(
        of symbolName: String,
        symbolType: String?
    ) async throws -> [String]
}
