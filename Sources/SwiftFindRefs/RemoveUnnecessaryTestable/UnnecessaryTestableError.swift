import Foundation

enum UnnecessaryTestableError: Error, LocalizedError {
    case failedToOpenIndexStore(String)
    case failedToLoadUnits(String)
    case duplicateRecord(String)
    case missingModuleInIndex(file: String, modules: Set<String>)
    case missingSourceLine(file: String, line: Int)

    var errorDescription: String? {
        switch self {
        case .failedToOpenIndexStore(let path):
            return "Failed to open index store at \(path)."
        case .failedToLoadUnits(let path):
            return "Failed to load units from index store at \(path)."
        case .duplicateRecord(let file):
            return "Found duplicate record for \(file)."
        case .missingModuleInIndex(let file, let modules):
            return "Some modules imported with @testable were not included in the index \(file): \(modules)"
        case .missingSourceLine(let file, let line):
            return "Could not read line \(line) in \(file)."
        }
    }
}
