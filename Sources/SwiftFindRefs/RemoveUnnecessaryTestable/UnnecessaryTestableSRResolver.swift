import Foundation
import IndexStore

/// Resolves symbol references for testable import analysis.
/// This resolver is specifically designed for unnecessary testable imports analysis (rmUTI).
enum UnnecessaryTestableSRResolver {
    /// Extracts the USRs of all referenced symbols from the occurrences in the main file.
    /// - Parameters:
    ///   - mainFile: The main source file to analyze.
    ///   - occurrencesByFile: A mapping of file paths to their symbol occurrences.
    ///   - Returns: A tuple containing a set of all referenced symbol USRs and a set of override symbol USRs.
    ///   - Note: Override symbols are those that are marked as overrides or bases of other symbols.
    ///   - Note: Collects from occurrences with .reference role (matching the example implementation).
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
