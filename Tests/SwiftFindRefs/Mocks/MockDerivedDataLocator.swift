import Foundation
@testable import SwiftFindRefs

final class MockDerivedDataLocator: DerivedDataLocatorProtocol {
    var locateDerivedDataResult: Result<DerivedDataPaths, Error>?

    func locateDerivedData(projectName: String?, derivedDataPath: String?) throws -> DerivedDataPaths {
        if let result = locateDerivedDataResult {
            switch result {
            case .success(let location):
                return location
            case .failure(let error):
                throw error
            }
        } else {
            fatalError("locateDerivedDataResult not set")
        }
    }
}
