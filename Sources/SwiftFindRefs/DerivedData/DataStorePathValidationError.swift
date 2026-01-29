import Foundation

/// Errors thrown while validating the DataPath  for a project.
enum DataStorePathValidationError: LocalizedError {
    case invalidPath(String)

    /// Human-readable description surfaced to end users.
    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            "❌ The provided DataStore path does not exist: \(path)."
        }
    }
}
