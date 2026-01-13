import Foundation
import IndexStore

struct IndexStoreFinder {
    let indexStorePath: String

    func fileReferences(of symbolName: String, symbolType: String?) throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        let query = SymbolQuery(name: symbolName, kindString: symbolType)
        let index = RecordIndex.build(from: store)
        
        return searchRecordsInParallel(store: store, index: index, query: query)
    }
    
    private func searchRecordsInParallel(
        store: IndexStore,
        index: RecordIndex,
        query: SymbolQuery
    ) -> [String] {
        let lock = NSLock()
        var referencedFiles = Set<String>()
        
        DispatchQueue.concurrentPerform(iterations: index.recordNames.count) { i in
            let recordName = index.recordNames[i]
            
            if recordContainsSymbol(store: store, recordName: recordName, query: query) {
                let filename = index.sourcePath(for: recordName)
                lock.lock()
                referencedFiles.insert(filename)
                lock.unlock()
            }
        }
        
        return referencedFiles.sorted()
    }
    
    private func recordContainsSymbol(
        store: IndexStore,
        recordName: String,
        query: SymbolQuery
    ) -> Bool {
        guard let recordReader = try? RecordReader(indexStore: store, recordName: recordName) else {
            return false
        }
        
        var found = false
        recordReader.forEach { (occurrence: SymbolOccurrence) in
            guard !found else { return }
            if query.matches(occurrence.symbol) {
                found = true
            }
        }
        return found
    }
}
