import Foundation

/// Abstraction defining minimal file system query capabilities.
///
/// Conforming types provide methods to check for file existence,
/// retrieve standard directory URLs, and enumerate directory contents.
/// - Note: Returned file path collections use absolute URL string representations for consistency.
protocol FileSystemProvider {
    /// Indicates whether a file or directory exists at the specified path.
    /// - Parameter path: A file or directory path (absolute or relative).
    /// - Returns: `true` if an item exists at the path; otherwise `false`.
    func fileExists(atPath path: String) -> Bool

    /// Returns the URL of the user's Library directory.
    func libraryDirectory() -> URL

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
    ) throws -> [URL]

    /// Reads the contents of a file as a string.
    /// - Parameter path: A file path (absolute or relative).
    func readFile(atPath path: String) throws -> String

    /// Reads the contents of a file as lines.
    /// - Parameter path: A file path (absolute or relative).
    func readLines(atPath path: String) throws -> [String]

    /// Writes the contents to a file path.
    /// - Parameters:
    ///   - contents: The string to write.
    ///   - path: A file path (absolute or relative).
    func writeFile(_ contents: String, toPath path: String) throws
}
