import IndexStore

enum OccurrenceRelationshipAnalyzer {
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
