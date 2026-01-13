import IndexStore

// MARK: - IndexStore Library Conformance

extension UnitDependency: UnitDependencyProviding {}

extension UnitReader: UnitReaderProviding {
    func forEachDependency(_ callback: (UnitDependencyProviding) -> Void) {
        forEach { dependency in
            callback(dependency)
        }
    }
}

extension IndexStore: IndexStoreProviding {
    func forEachUnit(_ callback: (UnitReaderProviding) -> Void) {
        for unit in units {
            callback(unit)
        }
    }
}
