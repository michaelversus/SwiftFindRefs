import Foundation

/// Abstraction defining minimal file system query capabilities.
///
/// Conforming types provide methods to check for file existence,
/// retrieve standard directory URLs, and enumerate directory contents.
/// - Note: Returned file path collections use absolute URL string representations for consistency.
protocol FileSystemProvider {
    /// The absolute path string of the current working directory.
    var currentDirectoryPath: String { get }
    
    /// Indicates whether a file or directory exists at the specified path.
    /// - Parameter path: A file or directory path (absolute or relative).
    /// - Returns: `true` if an item exists at the path; otherwise `false`.
    func fileExists(atPath path: String) -> Bool

    /// Returns the URL of the user's Library directory.
    /// - Returns: Absolute URL for the Library directory in the current user domain.
    func libraryDirectory() -> URL

    /// Returns the contents of the directory at the specified URL.
    /// - Parameters:
    ///   - url: The URL of the directory to read.
    ///   - keys: Resource keys to prefetch for each item.
    ///   - mask: Directory enumeration options that shape traversal behavior.
    /// - Returns: URLs for each item found in the directory.
    /// - Throws: An error if the directory cannot be read.
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL]

    /// Reads the contents of a file as a UTF-8 string.
    /// - Parameter path: A file path (absolute or relative).
    /// - Returns: Entire file contents as a single string.
    /// - Throws: An error if the file cannot be read or decoded as UTF-8.
    func readFile(atPath path: String) throws -> String

    /// Reads the contents of a file as an array of lines.
    /// - Parameter path: A file path (absolute or relative).
    /// - Returns: Strings representing each line, preserving empty lines.
    /// - Throws: An error if the file cannot be read.
    func readLines(atPath path: String) throws -> [String]

    /// Writes the provided contents to a file path using UTF-8 encoding.
    /// - Parameters:
    ///   - contents: The string to write.
    ///   - path: A file path (absolute or relative).
    /// - Throws: An error if the contents cannot be written to disk.
    func writeFile(_ contents: String, toPath path: String) throws
}
