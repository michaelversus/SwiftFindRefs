@testable import SwiftFindRefs

struct MockUnitReader: UnitReaderProviding, Sendable {
    let isSystem: Bool
    let dependencies: [MockUnitDependency]
    let mainFile: String
    let moduleName: String
    let recordName: String?

    init(
        isSystem: Bool,
        dependencies: [MockUnitDependency] = [],
        mainFile: String = "/mock/file.swift",
        moduleName: String = "MockModule",
        recordName: String? = "mock-record"
    ) {
        self.isSystem = isSystem
        self.dependencies = dependencies
        self.mainFile = mainFile
        self.moduleName = moduleName
        self.recordName = recordName
    }

    func forEachDependency(_ callback: (UnitDependencyProviding) -> Void) {
        dependencies.forEach { callback($0) }
    }
}
