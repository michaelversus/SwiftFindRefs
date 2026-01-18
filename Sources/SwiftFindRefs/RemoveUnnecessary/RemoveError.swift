import Foundation

/// Errors that occur while gathering and validating index store data for cleanup commands.
enum RemoveError: Error, LocalizedError {
    /// Cannot open the index store at the provided path.
    case failedToOpenIndexStore(String)
    /// Cannot load the units that describe files and symbols from an index store.
    case failedToLoadUnits(String)
    /// A file was seen more than once while constructing derived data.
    case duplicateRecord(String)
    /// One or more `@testable` imports are missing from the recorded index state.
    case missingModuleInIndex(file: String, modules: Set<String>)
    /// The expected source line could not be read, for example because the file changed.
    case missingSourceLine(file: String, line: Int)

    /// A localized description suitable for logging or user dialogs.
    var errorDescription: String? {
        switch self {
        case .failedToOpenIndexStore(let path):
            return "Failed to open index store at \(path)."
        case .failedToLoadUnits(let path):
            return "Failed to load units from index store at \(path)."
        case .duplicateRecord(let file):
            return "Found duplicate record for \(file)."
        case .missingModuleInIndex(let file, let modules):
            return "Some modules imported with were not included in the index \(file): \(modules)"
        case .missingSourceLine(let file, let line):
            return "Could not read line \(line) in \(file)."
        }
    }
}
