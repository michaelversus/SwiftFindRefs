import IndexStore

/// Helpers that inspect occurrence relationships to detect protocol inheritance scenarios.
enum OccurrenceRelationshipAnalyzer {
    /// Indicates whether the occurrence represents a protocol member declared inside a protocol.
    /// - Parameter occurrence: Snapshot describing the symbol occurrence to inspect.
    /// - Returns: `true` when the occurrence is a method or property whose related symbols include a protocol parent; otherwise `false`.
    static func isChildOfProtocol(occurrence: OccurrenceSnapshot) -> Bool {
        let protocolChildrenTypes: [SymbolKind] = [
            .instanceMethod, .classMethod, .staticMethod,
            .instanceProperty, .classProperty, .staticProperty,
        ]
        guard protocolChildrenTypes.contains(occurrence.symbolKind) else {
            return false
        }

        for related in occurrence.relatedSymbols {
            if related.roles.contains(.childOf) && related.kind == .protocol {
                return true
            }
        }
        return false
    }
}
