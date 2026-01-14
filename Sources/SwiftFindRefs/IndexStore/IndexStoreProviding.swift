import IndexStore

/// Protocol for unit dependency abstraction, enabling testability
protocol UnitDependencyProviding {
    var kind: DependencyKind { get }
    var name: String { get }
    var filePath: String { get }
}

/// Protocol for unit reader abstraction, enabling testability
protocol UnitReaderProviding {
    var isSystem: Bool { get }
    func forEachDependency(_ callback: (UnitDependencyProviding) -> Void)
}

/// Protocol for index store abstraction, enabling testability
protocol IndexStoreProviding {
    func forEachUnit(_ callback: (UnitReaderProviding) -> Void)
    func recordReader(for recordName: String) throws -> RecordReaderProviding?
}

/// Protocol for record reader abstraction, enabling testability
protocol RecordReaderProviding {
    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void)
}

/// Protocol for symbol occurrence abstraction, enabling testability
protocol SymbolOccurrenceProviding {
    var symbolMatching: SymbolMatching { get }
}
