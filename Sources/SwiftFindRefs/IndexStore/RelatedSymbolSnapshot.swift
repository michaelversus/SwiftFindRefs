import IndexStore

/// Lightweight snapshot describing a symbol that is related to an occurrence (e.g., parent or reference target).
struct RelatedSymbolSnapshot: Sendable {
    /// Kind of the related symbol, such as protocol, class, or method.
    let kind: SymbolKind
    /// Roles that the related symbol plays in the relationship (childOf, reference, etc.).
    let roles: SymbolRoles
}
