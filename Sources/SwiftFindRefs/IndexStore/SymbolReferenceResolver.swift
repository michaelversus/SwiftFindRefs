import IndexStore

enum SymbolReferenceResolver {
    static func getReferenceUSRs(
        mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]]
    ) -> (Set<String>, Set<String>) {
        guard let occurrences = occurrencesByFile[mainFile] else {
            return ([], [])
        }

        var usrs = Set<String>()
        var overrideUSRs = Set<String>()
        for occurrence in occurrences {
            if occurrence.roles.contains(.reference) {
                usrs.insert(occurrence.symbolUSR)
                if occurrence.roles.contains(.overrideOf) || occurrence.roles.contains(.baseOf) {
                    overrideUSRs.insert(occurrence.symbolUSR)
                }
            }
        }

        return (usrs, overrideUSRs)
    }
}
