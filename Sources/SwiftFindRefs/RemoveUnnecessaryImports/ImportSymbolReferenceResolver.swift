import Foundation
import IndexStore

/// Resolves symbol references for import analysis, collecting USRs and symbol names from referenced symbols.
/// This resolver is specifically designed for unnecessary imports analysis (rmUI) and includes
/// symbol name fallback matching to handle cases where USRs might not match.
enum ImportSymbolReferenceResolver {
    /// Extracts the USRs and names of all referenced symbols from the occurrences in the main file.
    /// - Parameters:
    ///   - mainFile: The main source file to analyze.
    ///   - occurrencesByFile: A mapping of file paths to their symbol occurrences.
    ///   - fileLines: Optional array of file lines for extracting typealias names from extension declarations.
    ///   - Returns: A tuple containing a set of all referenced symbol USRs, a set of override symbol USRs, a set of referenced symbol names, and a set of referenced typealias names.
    ///   - Note: Override symbols are those that are marked as overrides or bases of other symbols.
    ///   - Note: Typealiases are extracted from extension declarations (e.g., `extension [Int]` where [Int] is a typealias).
    ///   - Note: Collects from occurrences with .reference role (matching the example implementation).
    static func getReferenceUSRs(
        mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]],
        fileLines: [String]? = nil
    ) -> (Set<String>, Set<String>, Set<String>, Set<String>) {
        guard let occurrences = occurrencesByFile[mainFile] else {
            return ([], [], [], [])
        }

        var usrs = Set<String>()
        var overrideUSRs = Set<String>()
        var referencedNames = Set<String>()
        var typealiases = Set<String>()
        
        // Regex to match identifiers (matching the example: [a-zA-Z_][a-zA-Z0-9_]*)
        // Note: The example doesn't include brackets in the character class
        let identifierRegex = try! Regex("([a-zA-Z_][a-zA-Z0-9_]*)")
        
        for occurrence in occurrences {
            // Match the example implementation exactly:
            // 1. Collect USRs from swiftExtensionOfStruct subkind (we use .extension kind as proxy)
            // 2. Collect USRs from .reference role occurrences (for non-extension symbols)
            // The example uses "if ... else if" so extensions are handled separately
            if occurrence.symbolKind == .extension {
                // For extensions, collect the USR (like the example does for swiftExtensionOfStruct)
                // The example collects USR regardless of role for extensions
                usrs.insert(occurrence.symbolUSR)
                referencedNames.insert(occurrence.symbolName)
                
                // Extract typealias names from extension declarations
                // This handles cases like `extension [Int]` where [Int] is a typealias
                if let fileLines = fileLines,
                   occurrence.locationLine > 0,
                   occurrence.locationLine <= fileLines.count {
                    let lineIndex = occurrence.locationLine - 1
                    let line = fileLines[lineIndex]
                    
                    // Match the example exactly: use occurrence.location.column to find the exact start position
                    // The example's regex pattern is ([a-zA-Z_][a-zA-Z0-9_]*) - doesn't include brackets
                    // Add bounds checking to prevent crashes when column is out of bounds
                    guard occurrence.locationColumn > 0 && occurrence.locationColumn <= line.count + 1 else {
                        continue
                    }
                    let columnIndex = occurrence.locationColumn - 1
                    guard columnIndex < line.count else {
                        continue
                    }
                    let startIndex = line.index(line.startIndex, offsetBy: columnIndex)
                    guard startIndex < line.endIndex else {
                        continue
                    }
                    let lineFromColumn = line[startIndex...]
                    // Extract the identifier (could be a typealias like [Int])
                    // Match identifier pattern: [a-zA-Z_][a-zA-Z0-9_]* (matching the example)
                    guard let match = try? identifierRegex.firstMatch(in: String(lineFromColumn)) else {
                        continue
                    }
                    let identifier = String(match.0)
                    
                    // The example doesn't trim - it uses the identifier as-is
                    // Only add if identifier doesn't match the symbol name (like the example)
                    if identifier != occurrence.symbolName {
                        typealiases.insert(identifier)
                    }
                }
            } else if occurrence.roles.contains(.reference) {
                // Collect USRs and names from occurrences with .reference role (for non-extension symbols)
                usrs.insert(occurrence.symbolUSR)
                referencedNames.insert(occurrence.symbolName)
                if occurrence.roles.contains(.overrideOf) || occurrence.roles.contains(.baseOf) {
                    overrideUSRs.insert(occurrence.symbolUSR)
                }
            }
        }

        // Extract type names from static property access patterns (e.g., Settings.shared, TypeName.staticProperty)
        // IndexStore might only capture the property name, not the type name
        if let fileLines = fileLines {
            // Pattern: TypeName.staticProperty or TypeName.shared
            // Match: [A-Z][a-zA-Z0-9_]*\.[a-z][a-zA-Z0-9_]*
            let staticPropertyPattern = try! Regex(#"([A-Z][a-zA-Z0-9_]*)\.([a-z][a-zA-Z0-9_]*)"#)
            for line in fileLines {
                for match in line.matches(of: staticPropertyPattern) {
                    // Extract the type name (first capture group)
                    // match.output is a tuple with capture groups
                    let fullMatch = String(match.0)
                    // Try to extract type name by parsing the match
                    if let dotIndex = fullMatch.firstIndex(of: ".") {
                        let typeName = String(fullMatch[..<dotIndex])
                        if !typeName.isEmpty && typeName.first?.isUppercase == true {
                            referencedNames.insert(typeName)
                        }
                    }
                }
            }
        }

        return (usrs, overrideUSRs, referencedNames, typealiases)
    }
}
