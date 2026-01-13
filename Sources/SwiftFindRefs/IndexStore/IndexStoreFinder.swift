import Foundation
import IndexStore

struct IndexStoreFinder {
    let indexStorePath: String

    func fileReferences(of symbolName: String, symbolType: String?) throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        
        // Pre-compute SymbolKind enum to avoid string comparison in hot loop
        let expectedSymbolKind: SymbolKind? = symbolType.flatMap { parseSymbolKind($0) }

        // Collect all record dependencies with their source paths in a single pass
        var recordToSource: [String: String] = [:]
        var allRecordNames = Set<String>()

        for unitReader in store.units {
            // Skip system frameworks (SDK headers, etc.)
            guard !unitReader.isSystem else { continue }
            
            unitReader.forEach { dependency in
                guard dependency.kind == .record else { return }
                let recordName = dependency.name
                allRecordNames.insert(recordName)
                // Only store non-empty paths, prefer keeping existing paths
                let filePath = dependency.filePath
                if !filePath.isEmpty && recordToSource[recordName] == nil {
                    recordToSource[recordName] = filePath
                }
            }
        }

        // Convert to array for parallel processing
        let recordNames = Array(allRecordNames)
        let lock = NSLock()
        var referencedFiles = Set<String>()

        // Process records in parallel across all CPU cores
        DispatchQueue.concurrentPerform(iterations: recordNames.count) { index in
            let recordName = recordNames[index]
            guard let recordReader = try? RecordReader(indexStore: store, recordName: recordName) else {
                return
            }

            var foundInRecord = false
            recordReader.forEach { (occurrence: SymbolOccurrence) in
                guard !foundInRecord else { return }
                guard occurrence.symbol.name == symbolName else { return }
                if let expectedKind = expectedSymbolKind, occurrence.symbol.kind != expectedKind {
                    return
                }
                foundInRecord = true
            }

            if foundInRecord {
                let filename = recordToSource[recordName] ?? recordName
                lock.lock()
                referencedFiles.insert(filename)
                lock.unlock()
            }
        }

        return referencedFiles.sorted()
    }
    
    private func parseSymbolKind(_ type: String) -> SymbolKind? {
        switch type.lowercased() {
        case "class": return .class
        case "struct": return .struct
        case "enum": return .enum
        case "protocol": return .protocol
        case "function": return .function
        case "variable": return .variable
        case "typealias": return .typealias
        case "instancemethod": return .instanceMethod
        case "staticmethod": return .staticMethod
        case "classmethod": return .classMethod
        case "instanceproperty": return .instanceProperty
        case "staticproperty": return .staticProperty
        case "classproperty": return .classProperty
        case "constructor": return .constructor
        case "destructor": return .destructor
        case "field": return .field
        case "enumconstant": return .enumConstant
        case "parameter": return .parameter
        case "module": return .module
        case "extension": return .extension
        default: return nil
        }
    }
}
