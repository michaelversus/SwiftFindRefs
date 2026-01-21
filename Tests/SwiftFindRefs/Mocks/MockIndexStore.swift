@testable import SwiftFindRefs

struct MockIndexStore: IndexStoreProviding, Sendable {
    let units: [MockUnitReader]
    let recordReaders: [String: MockRecordReader]
    let recordReaderError: Error?

    init(
        units: [MockUnitReader],
        recordReaders: [String: MockRecordReader] = [:],
        recordReaderError: Error? = nil
    ) {
        self.units = units
        self.recordReaders = recordReaders
        self.recordReaderError = recordReaderError
    }

    func forEachUnit(_ callback: (UnitReaderProviding) -> Void) {
        units.forEach { callback($0) }
    }

    func recordReader(for recordName: String) throws -> RecordReaderProviding? {
        if let recordReaderError {
            throw recordReaderError
        }
        return recordReaders[recordName]
    }
}
