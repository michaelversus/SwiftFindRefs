import Foundation
@preconcurrency import IndexStore

struct IndexStoreFinder {
    let indexStorePath: String

    func fileReferences(of symbolName: String, symbolType: String?) throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        return try fileReferences(of: symbolName, symbolType: symbolType, from: store)
    }

    func fileReferences(
        of symbolName: String,
        symbolType: String?,
        from store: some IndexStoreProviding & Sendable
    ) throws -> [String] {
        let query = SymbolQuery(name: symbolName, kindString: symbolType)
        let index = RecordIndex.build(from: store)

        return searchRecordsInParallel(store: store, index: index, query: query)
    }

    private func searchRecordsInParallel(
        store: some IndexStoreProviding & Sendable,
        index: RecordIndex,
        query: SymbolQuery
    ) -> [String] {
        let referencedFiles = ThreadSafeSet<String>()

        DispatchQueue.concurrentPerform(iterations: index.recordNames.count) { i in
            let recordName = index.recordNames[i]

            if recordContainsSymbol(store: store, recordName: recordName, query: query) {
                let filename = index.sourcePath(for: recordName)
                referencedFiles.insert(filename)
            }
        }

        return referencedFiles.values().sorted()
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

private final class ThreadSafeSet<Element: Hashable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Set<Element>()

    func insert(_ element: Element) {
        lock.lock()
        storage.insert(element)
        lock.unlock()
    }

    func values() -> [Element] {
        lock.lock()
        let snapshot = Array(storage)
        lock.unlock()
        return snapshot
    }
}
