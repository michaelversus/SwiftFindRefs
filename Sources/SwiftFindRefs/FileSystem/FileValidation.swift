/// Namespace for helpers that classify files before further processing.
enum FileValidation {
    /// Indicates whether the provided path points to a generated Swift file that can be skipped.
    /// - Parameter path: Absolute or relative path of the file to inspect.
    /// - Returns: `true` for files ending in `.generated.swift` regardless of casing variant; otherwise `false`.
    static func isGeneratedFile(_ path: String) -> Bool {
        path.hasSuffix(".generated.swift") || path.hasSuffix(".Generated.swift")
    }

    /// Indicates whether the provided path points to a third-party file that should be skipped.
    /// - Parameter path: Absolute or relative path of the file to inspect.
    /// - Returns: `true` for files located in Xcode's system directories (containing "Library/Developer/Xcode"); otherwise `false`.
    static func isThirdPartyFile(_ path: String) -> Bool {
        path.contains("Library/Developer/Xcode")
    }

    /// Determines whether a file path is valid for removal scanning by checking all validation criteria.
    /// A file is valid if it is not generated, not a third-party file, and not in an excluded directory.
    /// - Parameters:
    ///   - path: The file path to check (can be absolute or relative).
    ///   - excludedDirectories: Array of directory paths or patterns to exclude. Paths are matched if the file path contains them.
    ///   - rootPath: The root path of the project, used to normalize relative exclusion paths.
    /// - Returns: `true` if the file is valid for removal scanning; otherwise `false`.
    static func isValidForRemoveScan(_ path: String, excludedDirectories: [String]?, rootPath: String) -> Bool {
        !isGeneratedFile(path) && !isThirdPartyFile(path) && !isExcludedDirectory(path, excludedDirectories: excludedDirectories, rootPath: rootPath)
    }

    /// Checks if a file path should be excluded based on a list of excluded directory patterns.
    /// - Parameters:
    ///   - path: The file path to check (can be absolute or relative).
    ///   - excludedDirectories: Array of directory paths or patterns to exclude. Paths are matched if the file path contains them.
    ///   - rootPath: The root path of the project, used to normalize relative exclusion paths.
    /// - Returns: `true` if the file should be excluded; otherwise `false`.
    static func isExcludedDirectory(_ path: String, excludedDirectories: [String]?, rootPath: String) -> Bool {
        guard let excludedDirectories = excludedDirectories, !excludedDirectories.isEmpty else {
            return false
        }

        // Normalize the file path to ensure consistent comparison
        let normalizedPath = path.hasPrefix("/") ? path : rootPath + path

        for excludedDir in excludedDirectories {
            // Normalize excluded directory path
            let normalizedExcludedDir: String
            if excludedDir.hasPrefix("/") {
                normalizedExcludedDir = excludedDir
            } else {
                normalizedExcludedDir = rootPath + excludedDir
            }

            // Ensure the excluded directory path ends with "/" for proper matching
            let dirPath = normalizedExcludedDir.hasSuffix("/") ? normalizedExcludedDir : normalizedExcludedDir + "/"

            // Check if the file path contains the excluded directory
            if normalizedPath.contains(dirPath) || normalizedPath == normalizedExcludedDir {
                return true
            }
        }

        return false
    }
}
