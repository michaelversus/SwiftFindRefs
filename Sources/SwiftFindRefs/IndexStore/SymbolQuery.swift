import IndexStore

/// Encapsulates the search criteria for finding symbols
struct SymbolQuery {
    let name: String
    let kind: SymbolKind?
    
    init(name: String, kindString: String?) {
        self.name = name
        self.kind = kindString.flatMap { SymbolKind(parsing: $0) }
    }
    
    func matches(_ symbol: Symbol) -> Bool {
        guard symbol.name == name else { return false }
        if let kind, symbol.kind != kind { return false }
        return true
    }
}
