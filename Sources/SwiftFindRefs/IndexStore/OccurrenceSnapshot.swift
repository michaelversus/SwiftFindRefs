import IndexStore

struct OccurrenceSnapshot: Sendable {
    let symbolKind: SymbolKind
    let roles: SymbolRoles
    let locationLine: Int
    let symbolUSR: String
    let relatedSymbols: [RelatedSymbolSnapshot]
}
