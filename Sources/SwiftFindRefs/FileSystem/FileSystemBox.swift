/// Type-erased wrapper that exposes a `FileSystemProvider` as `Sendable` for cross-actor sharing.
struct FileSystemBox: @unchecked Sendable {
    // FileManager is thread-safe for concurrent reads across different files.
    /// Underlying file system implementation that might not conform to `Sendable` itself.
    let fileSystem: FileSystemProvider
}
