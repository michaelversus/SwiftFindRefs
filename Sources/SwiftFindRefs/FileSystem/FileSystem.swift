import Foundation

/// Provides file system related utilities backed by `FileManager`.
///
/// `FileSystem` is the concrete implementation of `FileSystemProvider` used to
/// query the file system for file existence, standard directory locations
/// and directory contents.
///
/// - Note: All returned file path sets use absolute URL string representations.
final class FileSystem: FileSystemProvider {
    private let fileManager: FileManager

    // MARK: - Initialization

    /// Creates a new `FileSystem` instance.
    /// - Parameters:
    ///   - fileManager: The `FileManager` used for low level file operations. Defaults to `.default`.
    init(
        fileManager: FileManager = .default,
    ) {
        self.fileManager = fileManager
    }

    /// The absolute path string of the current working directory.
    /// Mirrors `FileManager.currentDirectoryPath`.
    var currentDirectoryPath: String {
        fileManager.currentDirectoryPath
    }

    // MARK: - File Queries

    /// Indicates whether a file or directory exists at the specified path.
    /// - Parameter path: The path whose existence is being checked.
    /// - Returns: `true` if a file system item exists at the path; otherwise `false`.
    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    /// Returns the URL of the user's Library directory.
    func libraryDirectory() -> URL {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
    }

    /// Returns the contents of the directory at the specified URL.
    /// - Parameters:
    ///  - url: The URL of the directory to read.
    ///  - keys: An array of resource keys to prefetch for each item.
    ///  - mask: Options for directory enumeration.
    ///  - Returns: An array of URLs for the items in the directory.
    ///  - Throws: An error if the directory cannot be read.
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: mask
        )
    }

    /// Reads the file contents at the provided path as a UTF-8 string.
    /// - Parameter path: Absolute or relative file system path for the file to read.
    /// - Returns: Entire file contents as a single string.
    /// - Throws: An error if the file cannot be opened or decoded as UTF-8.
    func readFile(atPath path: String) throws -> String {
        try String(contentsOfFile: path)
    }

    /// Reads the file and returns its content as an array of lines, preserving empties.
    /// - Parameter path: Path to the file whose lines should be returned.
    /// - Returns: Array of strings where each element represents a single line.
    /// - Throws: An error if the file cannot be read.
    func readLines(atPath path: String) throws -> [String] {
        // Read the file content first to preserve empty lines (including trailing ones)
        // URL.resourceBytes.lines strips trailing newlines, so we need to split manually
        let contents = try readFile(atPath: path)
        return contents.components(separatedBy: .newlines)
    }

    /// Writes the provided string to the destination path using UTF-8 encoding.
    /// - Parameters:
    ///   - contents: String to persist.
    ///   - path: Destination path on disk.
    /// - Throws: An error if the write fails.
    func writeFile(_ contents: String, toPath path: String) throws {
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
