@testable import SwiftFindRefs
import IndexStore

struct MockUnitDependency: UnitDependencyProviding {
    let kind: DependencyKind
    let name: String
    let filePath: String
}
