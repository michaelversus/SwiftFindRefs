import Foundation
import IndexStore

struct IndexStoreFinder {
    let indexStorePath: String

    func fileReferences(of symbolName: String, symbolType: String?) throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        let expectedKind = symbolType?.lowercased()

        // Collect all record dependencies with their source paths in a single pass
        var recordToSource: [String: String] = [:]
        var allRecordNames = Set<String>()

        for unitReader in store.units {
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

        // Process each record only once (deduplicated across all units)
        let referencedFiles: Set<String> = allRecordNames.reduce(into: []) { result, recordName in
            guard let recordReader = try? RecordReader(indexStore: store, recordName: recordName) else {
                return
            }

            var foundInRecord = false
            recordReader.forEach { (occurrence: SymbolOccurrence) in
                guard !foundInRecord else { return } // Skip if already found for this record
                guard occurrence.symbol.name == symbolName else { return }
                if let expectedKind,
                   occurrence.symbol.kind.description.lowercased() != expectedKind {
                    return
                }
                foundInRecord = true
            }

            if foundInRecord {
                let filename = recordToSource[recordName] ?? recordName
                result.insert(filename)
            }
        }

        return referencedFiles.sorted()
    }
}
