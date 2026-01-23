@testable import SwiftFindRefs

final class MockIndexStoreImportExtractor: IndexStoreImportExtracting {
    private(set) var actions: [Action] = []
    enum Action: Equatable {
        case imports(
            inMainFile: String,
            occurrencesByFile: [String : [String]],
            fileLines: [String],
            ignoredModules: Set<String>
        )
    }

    private let resultsByFile: [String: Set<String>]

    init(resultsByFile: [String: Set<String>] = [:]) {
        self.resultsByFile = resultsByFile
    }

    func imports(
        inMainFile mainFile: String,
        occurrencesByFile: [String : [OccurrenceSnapshot]],
        fileLines: [String],
        ignoredModules: Set<String>,
        vPrint: ((String) -> Void)? = nil
    ) -> Set<String> {
        actions.append(
            .imports(
                inMainFile: mainFile,
                occurrencesByFile: occurrencesByFile.mapValues { $0.map { $0.symbolName } },
                fileLines: fileLines,
                ignoredModules: ignoredModules
            )
        )
        
        return resultsByFile[mainFile] ?? []
    }
    
    func specificImports(
        inMainFile mainFile: String,
        fileLines: [String]
    ) -> [String: String?] {
        // Mock implementation - return empty for tests
        return [:]
    }
}
