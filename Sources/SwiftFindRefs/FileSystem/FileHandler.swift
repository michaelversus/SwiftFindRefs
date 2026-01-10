import Foundation

/// Provides utilities for handling file system enumeration.
///
/// `FileHandler` encapsulates pure functions that operate on `FileManager.DirectoryEnumerator` instances.
/// - Note: The passed `enumerator` is consumed; after calling `filterFiles(from:)` it will have advanced through all items.
///
/// Example usage:
/// ```swift
/// if let enumerator = FileManager.default.enumerator(at: someDirectoryURL, includingPropertiesForKeys: nil) {
///     let fileURLs = FileHandler.filterFiles(from: enumerator)
///     // `fileURLs` now contains only regular file URLs (directories excluded)
/// }
/// ```
enum FileHandler {
    /// Returns a set containing all non-directory file URLs produced by the provided directory enumerator.
    /// - Parameter enumerator: A `FileManager.DirectoryEnumerator` positioned at the start of traversal.
    /// - Returns: A set of file URLs excluding any directories encountered.
    /// - Important: The enumerator is exhausted by this call.
    /// - Complexity: O(n) where n is the number of entries yielded by the enumerator.
    /// - Thread Safety: Not thread-safe; use only from the thread that created the enumerator.
    static func filterFiles(
        from enumerator: FileManager.DirectoryEnumerator
    ) -> Set<URL> {
        var fileURLs = [URL]()
        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.hasDirectoryPath {
                continue
            } else {
                fileURLs.append(fileURL)
            }
        }
        return Set(fileURLs)
    }
}
