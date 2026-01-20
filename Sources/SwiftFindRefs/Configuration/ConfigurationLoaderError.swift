/// Errors thrown while attempting to locate and load a configuration JSON file.
///
/// Provides a distinct case for a missing file so callers can supply targeted remediation guidance
/// (e.g. instructing the user to create `.swift-find-refs.json`). Other I/O or decoding failures are surfaced
/// directly from the throwing APIs used by the loader.
///
/// Conforms to `CustomStringConvertible` for human-readable CLI / log output and `Equatable` for test assertions.
enum ConfigurationLoaderError: Error, CustomStringConvertible, Equatable {
    /// Configuration file was not found at the resolved absolute path.
    /// - Parameter path: The absolute path that was checked for existence.
    case configurationFileNotFound(String)

    /// Human-readable string describing the error suitable for printing in diagnostic output.
    var description: String {
        switch self {
        case .configurationFileNotFound(let path):
            "❌ Configuration file not found at path: \(path)"
        }
    }
}
