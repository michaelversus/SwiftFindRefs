import Foundation
@preconcurrency import IndexStore

/// Utility that queries an IndexStore database to locate the files referencing a target symbol.
struct IndexStoreFinder {
    /// Absolute path to the IndexStore directory used when instantiating the store on demand.
    let indexStorePath: String

    /// Builds an `IndexStore` from `indexStorePath` and searches for files referencing the symbol.
    /// - Parameters:
    ///   - symbolName: Name of the symbol being queried.
    ///   - symbolType: Optional symbol kind (function, class, etc.) to narrow the search.
    /// - Returns: Sorted list of unique file paths containing the symbol.
    /// - Throws: Errors thrown while opening the IndexStore or scanning records.
    func fileReferences(of symbolName: String, symbolType: String?) async throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        return try await fileReferences(of: symbolName, symbolType: symbolType, from: store)
    }

    /// Searches the provided store for files referencing the target symbol.
    /// - Parameters:
    ///   - symbolName: Name of the symbol being queried.
    ///   - symbolType: Optional symbol kind used to refine matches.
    ///   - store: IndexStore provider already initialized by the caller.
    /// - Returns: Sorted list of unique file paths containing the symbol.
    /// - Throws: Errors thrown while building the record index or reading records.
    func fileReferences(
        of symbolName: String,
        symbolType: String?,
        from store: some IndexStoreProviding & Sendable
    ) async throws -> [String] {
        let query = SymbolQuery(name: symbolName, kindString: symbolType)
        let index = RecordIndex.build(from: store)

        return await searchRecordsInParallel(store: store, index: index, query: query)
    }

    /// Walks all records concurrently, returning the sorted list of records that contain the symbol.
    /// - Parameters:
    ///   - store: IndexStore provider in which records are queried.
    ///   - index: Record index that maps record names to their source file paths.
    ///   - query: Symbol query describing the name and optional kind.
    /// - Returns: Sorted list of file paths whose records contain the symbol.
    private func searchRecordsInParallel(
        store: some IndexStoreProviding & Sendable,
        index: RecordIndex,
        query: SymbolQuery
    ) async -> [String] {
        await withTaskGroup(of: String?.self) { group in
            for recordName in index.recordNames {
                group.addTask {
                    guard recordContainsSymbol(store: store, recordName: recordName, query: query) else {
                        return nil
                    }
                    return index.sourcePath(for: recordName)
                }
            }
            
            var referencedFiles = Set<String>()
            for await filename in group {
                if let filename = filename {
                    referencedFiles.insert(filename)
                }
            }
            
            return Array(referencedFiles).sorted()
        }
    }

    /// Indicates whether the specified record contains at least one occurrence matching the query.
    /// - Parameters:
    ///   - store: IndexStore provider that exposes the record reader.
    ///   - recordName: Name of the record to inspect.
    ///   - query: Symbol query to match occurrences against.
    /// - Returns: `true` if the record includes a matching occurrence; otherwise `false`.
    private func recordContainsSymbol(
        store: some IndexStoreProviding,
        recordName: String,
        query: SymbolQuery
    ) -> Bool {
        guard let recordReader = try? store.recordReader(for: recordName) else {
            return false
        }

        var found = false
        recordReader.forEachOccurrence { occurrence in
            guard !found else { return }
            if query.matches(occurrence.symbolMatching) {
                found = true
            }
        }
        return found
    }
}
