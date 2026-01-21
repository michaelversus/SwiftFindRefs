import Foundation

/// Default implementation for extracting imports from IndexStore occurrences.
struct IndexStoreImportExtractor: IndexStoreImportExtracting {
    init() {}

    func imports(
        inMainFile mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]],
        fileLines: [String],
        allModuleNames: Set<String>,
        ignoredModules: Set<String>
    ) -> Set<String> {
        guard let occurrences = occurrencesByFile[mainFile] else {
            return []
        }

        var imports = Set<String>()
        let ignoreRegex = try! Regex(#"// *@ignore-import$"#)

        for occurrence in occurrences {
            guard occurrence.symbolKind == .module, occurrence.roles.contains(.reference) else {
                continue
            }

            let lineIndex = occurrence.locationLine - 1
            guard lineIndex >= 0, lineIndex < fileLines.count else {
                continue
            }

            let line = fileLines[lineIndex]

            // Validate that this is actually an import statement (not a comment or a string literal).
            // Note: We keep the existing behavior matching the previous implementation.
            guard line.hasPrefix("import ") || line.contains(" import ") else {
                continue
            }

            if line.firstMatch(of: ignoreRegex) != nil {
                continue
            }

            // Parse module name from the actual line content, not from IndexStore symbolName.
            // IndexStore module symbols can be incorrect, so we parse the line directly.
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let prefix: String
            if trimmed.hasPrefix("@testable import ") {
                prefix = "@testable import "
            } else if trimmed.hasPrefix("import ") {
                prefix = "import "
            } else {
                continue
            }

            let modulePart = trimmed.dropFirst(prefix.count)
            guard
                let moduleNamePart = modulePart.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "." || $0 == "/" }).first,
                !moduleNamePart.isEmpty
            else {
                continue
            }

            let moduleName = String(moduleNamePart)

            guard allModuleNames.contains(moduleName), !ignoredModules.contains(moduleName) else {
                continue
            }

            imports.insert(moduleName)
        }

        return imports
    }
}
