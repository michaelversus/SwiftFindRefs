@testable import SwiftFindRefs

struct MockRecordReader: RecordReaderProviding, Sendable {
    let occurrences: [MockSymbolOccurrence]
    
    func forEachOccurrence(_ callback: (SymbolOccurrenceProviding) -> Void) {
        occurrences.forEach { callback($0) }
    }
}
