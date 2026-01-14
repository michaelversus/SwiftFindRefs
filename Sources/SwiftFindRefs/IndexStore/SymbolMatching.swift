import IndexStore

/// Protocol for symbol matching, enabling testability
protocol SymbolMatching {
    var name: String { get }
    var kind: SymbolKind { get }
}

extension Symbol: SymbolMatching {}
