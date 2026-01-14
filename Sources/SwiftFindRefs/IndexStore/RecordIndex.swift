import IndexStore

/// Maps record names to their source file paths
struct RecordIndex {
    let recordNames: [String]
    private let recordToSource: [String: String]
    
    /// Internal initializer for testing
    init(recordNames: [String], recordToSource: [String: String] = [:]) {
        self.recordNames = recordNames
        self.recordToSource = recordToSource
    }
    
    func sourcePath(for recordName: String) -> String {
        recordToSource[recordName] ?? recordName
    }
    
    static func build(from store: some IndexStoreProviding) -> RecordIndex {
        var recordToSource: [String: String] = [:]
        var allRecordNames = Set<String>()
        
        store.forEachUnit { unitReader in
            guard !unitReader.isSystem else { return }
            
            unitReader.forEachDependency { dependency in
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
