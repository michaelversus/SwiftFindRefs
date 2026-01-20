/// Namespace for helpers that classify files before further processing.
enum FileValidation {
    /// Indicates whether the provided path points to a generated Swift file that can be skipped.
    /// - Parameter path: Absolute or relative path of the file to inspect.
    /// - Returns: `true` for files ending in `.generated.swift` regardless of casing variant; otherwise `false`.
    static func isGeneratedFile(_ path: String) -> Bool {
        path.hasSuffix(".generated.swift") || path.hasSuffix(".Generated.swift")
    }

    static func isThirdPartyFile(_ path: String) -> Bool {
        path.contains("Library/Developer/Xcode")
    }
}
