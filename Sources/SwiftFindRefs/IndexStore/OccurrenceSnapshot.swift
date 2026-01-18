import IndexStore

/// Lightweight representation of a symbol occurrence captured from IndexStore queries.
struct OccurrenceSnapshot: Sendable {
    /// Kind of symbol associated with the occurrence (method, property, etc.).
    let symbolKind: SymbolKind
    /// Roles that the symbol plays within the occurrence (definition, reference, call, etc.).
    let roles: SymbolRoles
    /// 1-based line number where the symbol appears within its source file.
    let locationLine: Int
    /// Unique symbol resolution identifier that disambiguates the symbol across modules.
    let symbolUSR: String
    /// Related symbols attached to the occurrence, such as parents or referenced declarations.
    let relatedSymbols: [RelatedSymbolSnapshot]
}
