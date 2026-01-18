import IndexStore
/// Represents a snapshot of a compilation unit in the Index Store
struct UnitSnapshot: Sendable {
    let mainFile: String
    let moduleName: String
}
