import IndexStore

// MARK: - IndexStore Library Conformance

extension UnitDependency: UnitDependencyProviding {}

extension UnitReader: UnitReaderProviding {
    /// Iterates through the unit's dependencies and forwards each one to the provided callback.
    func forEachDependency(_ callback: (UnitDependencyProviding) -> Void) {
        forEach { dependency in
            callback(dependency)
        }
    }
}

extension IndexStore: IndexStoreProviding {
    /// Visits every compilation unit contained in the index store, exposing it through the provider protocol.
    func forEachUnit(_ callback: (UnitReaderProviding) -> Void) {
        for unit in units {
            callback(unit)
        }
    }

    /// Creates a record reader that conforms to `RecordReaderProviding` for the given record name.
    /// - Parameter recordName: Identifier of the index store record to inspect.
    /// - Returns: A provider-compatible reader when the record can be opened; otherwise `nil`.
    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        try? RecordReader(indexStore: self, recordName: recordName)
    }
}

extension RecordReader: RecordReaderProviding {
    /// Iterates over every symbol occurrence in the record and forwards it to the callback.
    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void) {
        forEach { occurrence in
            callback(occurrence)
        }
    }
}

extension SymbolOccurrence: SymbolOccurrenceProviding {
    /// Underlying symbol metadata used for protocol-based matching.
    var symbolMatching: SymbolMatching {
        symbol
    }

    /// Source line number where the occurrence resides.
    var locationLine: Int {
        location.line
    }

    /// Unified Symbol Resolution (USR) identifier for the symbol.
    var symbolUSR: String {
        symbol.usr
    }

    /// Iterates over each related symbol and forwards the pair of symbol and roles to the callback.
    func forEachRelatedSymbol(_ callback: (RelatedSymbolProviding, SymbolRoles) -> Void) {
        forEach { symbol, roles in
            callback(symbol, roles)
        }
    }
}

/// Declares `Symbol` as conforming to `RelatedSymbolProviding` for protocol-based abstraction.
extension Symbol: RelatedSymbolProviding {}
