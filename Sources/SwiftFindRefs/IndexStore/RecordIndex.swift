import IndexStore

/// Maps record names to their source file paths
struct RecordIndex {
    let recordNames: [String]
    private let recordToSource: [String: String]
    
    func sourcePath(for recordName: String) -> String {
        recordToSource[recordName] ?? recordName
    }
    
    static func build(from store: IndexStore) -> RecordIndex {
        var recordToSource: [String: String] = [:]
        var allRecordNames = Set<String>()
        
        for unitReader in store.units where !unitReader.isSystem {
            unitReader.forEach { dependency in
                guard dependency.kind == .record else { return }
                let recordName = dependency.name
                allRecordNames.insert(recordName)
                let filePath = dependency.filePath
                if !filePath.isEmpty && recordToSource[recordName] == nil {
                    recordToSource[recordName] = filePath
                }
            }
        }
        
        return RecordIndex(
            recordNames: Array(allRecordNames),
            recordToSource: recordToSource
        )
    }
}
