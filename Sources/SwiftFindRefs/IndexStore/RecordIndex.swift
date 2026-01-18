import IndexStore

/// Maps IndexStore record identifiers to their originating source file paths.
struct RecordIndex {
    /// Ordered list of record names discovered during index traversal.
    let recordNames: [String]
    /// Lookup table that resolves record names to concrete file-system paths.
    private let recordToSource: [String: String]

    /// Creates a record index using explicit record names and an optional lookup override.
    /// - Parameters:
    ///   - recordNames: Ordered identifiers that should be exposed by the index.
    ///   - recordToSource: Optional mapping that resolves each record to its source file path.
    init(recordNames: [String], recordToSource: [String: String] = [:]) {
        self.recordNames = recordNames
        self.recordToSource = recordToSource
    }

    /// Resolves the source path for the given record, defaulting to the record name when absent.
    /// - Parameter recordName: Identifier returned by IndexStore for a specific record.
    /// - Returns: Absolute or relative path to the source file that produced the record.
    func sourcePath(for recordName: String) -> String {
        recordToSource[recordName] ?? recordName
    }

    /// Builds a `RecordIndex` by scanning the provided IndexStore for non-system units and their record dependencies.
    /// - Parameter store: Index store abstraction to inspect.
    /// - Returns: A populated record index containing all discovered records plus their source mappings when available.
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
