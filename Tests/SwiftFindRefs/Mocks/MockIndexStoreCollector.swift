@testable import SwiftFindRefs

struct MockIndexStoreCollector: IndexStoreCollecting {

    private let result: Result<([UnitReaderProviding], [String: [OccurrenceSnapshot]]), Error>

    init(
        result: Result<([UnitReaderProviding], [String: [OccurrenceSnapshot]]), Error> = .success(([], [:]))
    ) {
        self.result = result
    }

    func collectUnitsAndRecords() throws -> ([UnitReaderProviding], [String: [OccurrenceSnapshot]]) {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
