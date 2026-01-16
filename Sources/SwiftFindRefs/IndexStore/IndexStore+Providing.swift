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
    
    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        try? RecordReader(indexStore: self, recordName: recordName)
    }
}

extension RecordReader: RecordReaderProviding {
    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void) {
        forEach { occurrence in
            callback(occurrence)
        }
    }
}

extension SymbolOccurrence: SymbolOccurrenceProviding {
    var symbolMatching: SymbolMatching {
        symbol
    }

    var locationLine: Int {
        location.line
    }

    var symbolUSR: String {
        symbol.usr
    }

    func forEachRelatedSymbol(_ callback: (RelatedSymbolProviding, SymbolRoles) -> Void) {
        forEach { symbol, roles in
            callback(symbol, roles)
        }
    }
}

extension Symbol: RelatedSymbolProviding {}
