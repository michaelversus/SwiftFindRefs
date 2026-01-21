@testable import SwiftFindRefs
import IndexStore

struct MockSymbol: SymbolMatching, Sendable {
    let kind: SymbolKind
    let name: String
    let usr: String

    init(
        kind: SymbolKind,
        name: String,
        usr: String = ""
    ) {
        self.kind = kind
        self.name = name
        self.usr = usr
    }
}
