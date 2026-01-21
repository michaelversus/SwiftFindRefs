@testable import SwiftFindRefs
import IndexStore

struct MockRelatedSymbol: RelatedSymbolProviding, Sendable {
    let kind: SymbolKind
}
