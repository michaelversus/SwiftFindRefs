/// Actor that caches line arrays per file to avoid repeated disk reads across asynchronous callers.
actor FileLinesCache {
    private var cache: [String: [String]] = [:]
    private let readLines: @Sendable (String) throws -> [String]

    /// Creates a cache backed by the injected line reader.
    init(
        readLines: @escaping @Sendable (String) throws -> [String]
    ) {
        self.readLines = readLines
    }

    /// Returns cached lines for the requested file, memoizing them on first access.
    func lines(for file: String) -> [String] {
        if let cached = cache[file] {
            return cached
        }
        let lines = (try? readLines(file)) ?? []
        cache[file] = lines
        return lines
    }
}
