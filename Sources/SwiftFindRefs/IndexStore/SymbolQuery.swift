import IndexStore

/// Encapsulates the search criteria for finding symbols.
struct SymbolQuery {
    /// Name of the symbol to match against occurrences.
    let name: String
    /// Optional symbol kind filter that narrows the search when provided.
    let kind: SymbolKind?

    /// Creates a symbol query from a symbol name and optional textual kind description.
    /// - Parameters:
    ///   - name: The symbol name to match exactly.
    ///   - kindString: Optional textual representation of the symbol kind (e.g., "class", "function").
    init(name: String, kindString: String?) {
        self.name = name
        self.kind = kindString.flatMap { SymbolKind(parsing: $0) }
    }

    /// Indicates whether the provided symbol matches the query's name and optional kind filter.
    /// - Parameter symbol: Symbol metadata to compare against the query.
    /// - Returns: `true` if the symbol name matches and, when specified, the kind matches as well.
    func matches(_ symbol: some SymbolMatching) -> Bool {
        guard symbol.name == name else { return false }
        if let kind, symbol.kind != kind { return false }
        return true
    }
}
