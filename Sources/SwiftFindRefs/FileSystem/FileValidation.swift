enum FileValidation {
    static func isGeneratedFile(_ path: String) -> Bool {
        path.hasSuffix(".generated.swift") || path.hasSuffix(".Generated.swift")
    }
}
