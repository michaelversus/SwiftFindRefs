import Testing
@testable import SwiftFindRefs

@Suite("RemoveError Tests")
struct UnnecessaryTestableErrorTests {
    @Test("failedToOpenIndexStore errorDescription includes path")
    func test_failedToOpenIndexStore_ErrorDescription() {
        let path = "/mock/index"
        let error = RemoveError.failedToOpenIndexStore(path)
        #expect(error.errorDescription == "Failed to open index store at \(path).")
    }

    @Test("failedToLoadUnits errorDescription includes path")
    func test_failedToLoadUnits_ErrorDescription() {
        let path = "/mock/index"
        let error = RemoveError.failedToLoadUnits(path)
        #expect(error.errorDescription == "Failed to load units from index store at \(path).")
    }

    @Test("duplicateRecord errorDescription includes file")
    func test_duplicateRecord_ErrorDescription() {
        let file = "/mock/File.swift"
        let error = RemoveError.duplicateRecord(file)
        #expect(error.errorDescription == "Found duplicate record for \(file).")
    }

    @Test("missingModuleInIndex errorDescription includes file and modules")
    func test_missingModuleInIndex_ErrorDescription() {
        let file = "/mock/File.swift"
        let modules: Set<String> = ["ModuleA", "ModuleB"]
        let error = RemoveError.missingModuleInIndex(file: file, modules: modules)
        #expect(
            error.errorDescription ==
                "Some modules imported with were not included in the index \(file): \(modules)"
        )
    }

    @Test("missingSourceLine errorDescription includes file and line")
    func test_missingSourceLine_ErrorDescription() {
        let file = "/mock/File.swift"
        let line = 42
        let error = RemoveError.missingSourceLine(file: file, line: line)
        #expect(error.errorDescription == "Could not read line \(line) in \(file).")
    }

    @Test("corruptedIndexStoreDB errorDescription includes file and guidance")
    func test_corruptedIndexStoreDB_ErrorDescription() {
        let file = "/mock/File.swift"
        let error = RemoveError.corruptedIndexStoreDB(file: file)
        #expect(
            error.errorDescription ==
                "IndexStoreDB is corrupted for \(file). Import statements found in the source file are missing from IndexStore. Please clean derived data and rebuild using Xcode to reconstruct indexes."
        )
    }
}
