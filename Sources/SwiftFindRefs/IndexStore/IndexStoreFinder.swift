import Foundation
@preconcurrency import IndexStore

struct IndexStoreFinder {
    let indexStorePath: String

    func fileReferences(of symbolName: String, symbolType: String?) async throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        return try await fileReferences(of: symbolName, symbolType: symbolType, from: store)
    }

    func fileReferences(
        of symbolName: String,
        symbolType: String?,
        from store: some IndexStoreProviding & Sendable
    ) async throws -> [String] {
        let query = SymbolQuery(name: symbolName, kindString: symbolType)
        let index = RecordIndex.build(from: store)

        return await searchRecordsInParallel(store: store, index: index, query: query)
    }

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
