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
    var mainFile: String { get }
    var moduleName: String { get }
    var recordName: String? { get }
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
    var roles: SymbolRoles { get }
    var locationLine: Int { get }
    var locationColumn: Int { get }
    var symbolUSR: String { get }
    func forEachRelatedSymbol(_ callback: (RelatedSymbolProviding, SymbolRoles) -> Void)
}

/// Protocol for related symbols attached to a symbol occurrence.
protocol RelatedSymbolProviding {
    var kind: SymbolKind { get }
}
