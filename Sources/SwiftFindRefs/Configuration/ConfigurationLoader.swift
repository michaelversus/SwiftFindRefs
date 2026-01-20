import Foundation

/// Loads a `Configuration` from a JSON file on disk applying flexible path resolution rules.
///
/// Resolution rules:
/// - If `path` is non-nil and absolute (starts with "/"), it is used directly.
/// - If `path` is non-nil and relative, it is appended to `root`.
/// - If `path` is nil, `defaultPath` is appended to `root`.
///
/// After resolution the loader verifies the file exists, prints a diagnostic message, then decodes the JSON.
/// Throws a typed error when the file is missing allowing callers to differentiate missing vs decoding failures.
struct ConfigurationLoader {
    /// File system abstraction used to verify existence of the configuration file before reading.
    let fileSystem: FileSystemProvider
    /// Default relative configuration filename used when the caller supplies no explicit path (defaults to `.swift-find-refs.json`).
    let defaultPath: String
    /// Diagnostic logging closure (intentionally named `print` for clarity at call sites) invoked with progress messages.
    let print: (String) -> Void

    /// Creates a loader.
    /// - Parameters:
    ///   - fileSystem: Provider used to check for file existence.
    ///   - defaultPath: Fallback relative path when `path` is nil (defaults to `.swift-find-refs.json`).
    ///   - print: Closure used to emit human-readable progress or diagnostic lines.
    init(
        fileSystem: FileSystemProvider,
        defaultPath: String = ".swift-find-refs.json",
        print: @escaping (String) -> Void
    ) {
        self.fileSystem = fileSystem
        self.defaultPath = defaultPath
        self.print = print
    }

    /// Resolves a configuration file path then loads and decodes a `Configuration`.
    ///
    /// Path resolution strategy:
    /// - Absolute provided `path` is used verbatim.
    /// - Relative provided `path` is prefixed with `root`.
    /// - Nil `path` becomes `root + defaultPath`.
    ///
    /// Emits a diagnostic line with the resolved path prior to decoding.
    /// - Parameters:
    ///   - path: Optional absolute or relative path string to the configuration JSON file.
    ///   - root: Root directory prefix used when `path` is relative or nil.
    /// - Returns: Decoded `Configuration` value.
    /// - Throws: `ConfigurationLoaderError.configurationFileNotFound` when the resolved file does not exist.
    ///           Any underlying I/O or decoding error produced by `Data(contentsOf:)` or `JSONDecoder.decode`.
    func loadConfiguration(at path: String?, root: String) throws -> Configuration {
        let configurationPath: String
        if let path {
            configurationPath = path.hasPrefix("/") ? path : root + path
        } else {
            configurationPath = root + defaultPath
        }
        guard fileSystem.fileExists(atPath: configurationPath) else {
            throw ConfigurationLoaderError.configurationFileNotFound(configurationPath)
        }
        print("Loading configuration from: \(configurationPath)")
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        let decoder = JSONDecoder()
        let configuration = try decoder.decode(Configuration.self, from: data)
        return configuration
    }
}
