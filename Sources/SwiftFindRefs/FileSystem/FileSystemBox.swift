
struct FileSystemBox: @unchecked Sendable {
    // FileManager is thread-safe for concurrent reads across different files.
    let fileSystem: FileSystemProvider
}
