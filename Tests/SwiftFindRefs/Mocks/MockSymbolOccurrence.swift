@testable import SwiftFindRefs
import IndexStore

struct MockSymbolOccurrence: SymbolOccurrenceProviding, Sendable {
    let symbol: MockSymbol
    let roles: SymbolRoles
    let locationLine: Int
    let locationColumn: Int
    let symbolUSR: String
    let relatedSymbols: [(MockRelatedSymbol, SymbolRoles)]

    init(
        symbolName: String,
        symbolKind: SymbolKind = .class,
        roles: SymbolRoles = [],
        locationLine: Int = 1,
        locationColumn: Int = 1,
        symbolUSR: String = "mock.usr",
        relatedSymbols: [(MockRelatedSymbol, SymbolRoles)] = []
    ) {
        symbol = MockSymbol(kind: symbolKind, name: symbolName, usr: symbolUSR)
        self.roles = roles
        self.locationLine = locationLine
        self.locationColumn = locationColumn
        self.symbolUSR = symbolUSR
        self.relatedSymbols = relatedSymbols
    }

    init(
        symbol: MockSymbol,
        roles: SymbolRoles = [],
        locationLine: Int = 1,
        locationColumn: Int = 1,
        symbolUSR: String = "mock.usr",
        relatedSymbols: [(MockRelatedSymbol, SymbolRoles)] = []
    ) {
        self.symbol = symbol
        self.roles = roles
        self.locationLine = locationLine
        self.locationColumn = locationColumn
        self.symbolUSR = symbolUSR
        self.relatedSymbols = relatedSymbols
    }

    var symbolMatching: SymbolMatching {
        symbol
    }

    func forEachRelatedSymbol(_ callback: (RelatedSymbolProviding, SymbolRoles) -> Void) {
        relatedSymbols.forEach { callback($0.0, $0.1) }
    }
}
