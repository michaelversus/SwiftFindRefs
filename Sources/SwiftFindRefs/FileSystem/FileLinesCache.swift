actor FileLinesCache {
    private var cache: [String: [String]] = [:]
    private let readLines: @Sendable (String) throws -> [String]

    init(
        readLines: @escaping @Sendable (String) throws -> [String]
    ) {
        self.readLines = readLines
    }

    func lines(for file: String) -> [String] {
        if let cached = cache[file] {
            return cached
        }
        let lines = (try? readLines(file)) ?? []
        cache[file] = lines
        return lines
    }
}
