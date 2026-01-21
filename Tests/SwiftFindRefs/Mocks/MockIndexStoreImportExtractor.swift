@testable import SwiftFindRefs

final class MockIndexStoreImportExtractor: IndexStoreImportExtracting {
    private(set) var actions: [Action] = []
    enum Action: Equatable {
        case imports(
            inMainFile: String,
            occurrencesByFile: [String : [String]],
            fileLines: [String],
            allModuleNames: Set<String>,
            ignoredModules: Set<String>
        )
    }

    private let result: Set<String>

    init(result: Set<String> = []) {
        self.result = result
    }

    func imports(
        inMainFile mainFile: String,
        occurrencesByFile: [String : [OccurrenceSnapshot]],
        fileLines: [String],
        allModuleNames: Set<String>,
        ignoredModules: Set<String>
    ) -> Set<String> {
        actions.append(
            .imports(
                inMainFile: mainFile,
                occurrencesByFile: occurrencesByFile.mapValues { $0.map { $0.symbolName } },
                fileLines: fileLines,
                allModuleNames: allModuleNames,
                ignoredModules: ignoredModules
            )
        )
        return result
    }
}
