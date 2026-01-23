import Foundation

/// Default implementation for extracting imports from IndexStore occurrences.
struct IndexStoreImportExtractor: IndexStoreImportExtracting {
    init() {}

    func imports(
        inMainFile mainFile: String,
        occurrencesByFile: [String: [OccurrenceSnapshot]],
        fileLines: [String],
        ignoredModules: Set<String>,
        vPrint: ((String) -> Void)? = nil
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
            let parts = modulePart.split(whereSeparator: { $0 == " " || $0 == "\t" })
            let specificImportKeywords = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
            
            let moduleName: String
            if let firstPart = parts.first,
               specificImportKeywords.contains(String(firstPart)),
               parts.count >= 2 {
                // Specific import: import struct Module.Symbol
                // Extract module name from "Module.Symbol" part
                let moduleAndSymbol = String(parts[1])
                if let dotIndex = moduleAndSymbol.firstIndex(of: ".") {
                    moduleName = String(moduleAndSymbol[..<dotIndex])
                } else {
                    // No dot, so the second part is the module name
                    moduleName = moduleAndSymbol
                }
            } else if let firstPart = parts.first {
                // Regular import: import Module
                let moduleNameString = String(firstPart)
                // Validate it's a valid identifier (starts with letter/underscore, contains alphanumeric/underscore)
                // Reject invalid imports like "import  ." where firstPart would be "."
                guard moduleNameString.first?.isLetter == true || moduleNameString.first == "_" else {
                    continue
                }
                // Split by dot/slash to get just the module name (not submodules)
                if let moduleNamePart = firstPart.split(whereSeparator: { $0 == "." || $0 == "/" }).first {
                    moduleName = String(moduleNamePart)
                } else {
                    moduleName = moduleNameString
                }
            } else {
                continue
            }
            
            guard !moduleName.isEmpty && (moduleName.first?.isLetter == true || moduleName.first == "_") else {
                continue
            }

            // Only filter by ignoredModules here
            // System frameworks (UIKit, Foundation, etc.) should be extracted too
            // The analyzer will handle filtering logic later
            if ignoredModules.contains(moduleName) {
                continue
            }

            imports.insert(moduleName)
        }
        return imports
    }
    
    func specificImports(
        inMainFile mainFile: String,
        fileLines: [String]
    ) -> [String: String?] {
        var specificImports: [String: String?] = [:]
        let specificImportKeywords = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
        
        for (_, line) in fileLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for specific imports: import struct/class/enum/protocol/typealias/func/var Module.Symbol
            guard trimmed.hasPrefix("import ") || trimmed.hasPrefix("@testable import ") else {
                continue
            }
            
            // Skip @testable imports (they're handled differently)
            guard trimmed.hasPrefix("import ") else {
                continue
            }
            
            let importPart = trimmed.dropFirst("import ".count)
            let parts = importPart.split(whereSeparator: { $0 == " " || $0 == "\t" })
            
            // Check if this is a specific import: import struct Module.Symbol
            if let firstPart = parts.first,
               specificImportKeywords.contains(String(firstPart)),
               parts.count >= 2 {
                // Extract module and symbol: Module.Symbol
                let moduleAndSymbol = parts.dropFirst().joined(separator: " ")
                if let dotIndex = moduleAndSymbol.firstIndex(of: ".") {
                    let symbolName = String(moduleAndSymbol[moduleAndSymbol.index(after: dotIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                    if !symbolName.isEmpty {
                        specificImports[line] = symbolName
                    }
                }
            } else {
                // Regular import - no specific symbol
                specificImports[line] = nil
            }
        }
        
        return specificImports
    }
}
