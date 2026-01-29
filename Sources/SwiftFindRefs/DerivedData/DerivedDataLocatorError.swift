import Foundation

/// Errors thrown while locating the DerivedData directory for a project.
enum DerivedDataLocatorError: LocalizedError {
    /// No usable `projectName` or `dataStorePath` was provided.
    case missingInputs
    /// The default DerivedData root directory does not exist at the expected path.
    case derivedDataRootMissing(String)
    /// A DerivedData entry matching the provided project name was not found.
    case projectNotFound(String)

    /// Human-readable description surfaced to end users.
    var errorDescription: String? {
        switch self {
        case .missingInputs:
            "❌ Either projectName or dataStorePath must be provided."
        case .derivedDataRootMissing(let path):
            "❌ DerivedData root directory was not found at \(path)."
        case .projectNotFound(let name):
            "❌ No DerivedData entry matching project \(name) was found."
        }
    }
}
