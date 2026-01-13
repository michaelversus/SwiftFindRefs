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
}
