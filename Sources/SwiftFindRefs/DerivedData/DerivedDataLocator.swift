import Foundation

/// Resolves the appropriate DerivedData directory either by explicit path or by inferring the latest entry for a project.
struct DerivedDataLocator: DerivedDataLocatorProtocol {
    private let fileSystem: FileSystemProvider
    private let derivedDataRoot: URL

    /// Creates a locator that uses the provided file system abstraction to interact with the disk.
    /// - Parameter fileSystem: The file system helper used to query directories and file existence.
    init(
        fileSystem: FileSystemProvider
    ) {
        self.fileSystem = fileSystem
        let libraryURL = fileSystem.libraryDirectory()
        self.derivedDataRoot = libraryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("Xcode", isDirectory: true)
            .appendingPathComponent("DerivedData", isDirectory: true)
    }

    /// Finds the DerivedData directory for the given inputs and indicates whether helper paths should be appended.
    /// - Parameters:
    ///   - projectName: The name of the Xcode project whose DerivedData should be inferred when no explicit path is supplied.
    ///   - derivedDataPath: An optional explicit DerivedData path which, when present, takes precedence over project resolution.
    /// - Returns: A ``DerivedDataPaths`` value containing the resolved URL and whether additional IndexStore paths should be appended.
    /// - Throws: ``DerivedDataLocatorError`` when inputs are missing, invalid, or when the DerivedData directory cannot be found.
    func locateDerivedData(
        projectName: String?,
        derivedDataPath: String?
    ) throws -> DerivedDataPaths {
        if let derivedDataPath, !derivedDataPath.isEmpty {
            guard fileSystem.fileExists(atPath: derivedDataPath) else {
                throw DerivedDataLocatorError.invalidPath(derivedDataPath)
            }
            return DerivedDataPaths(derivedDataURL: URL(fileURLWithPath: derivedDataPath), shouldAppendExtraPaths: false)
        }

        guard let projectName, !projectName.isEmpty else {
            throw DerivedDataLocatorError.missingInputs
        }

        guard fileSystem.fileExists(atPath: derivedDataRoot.path) else {
            throw DerivedDataLocatorError.derivedDataRootMissing(derivedDataRoot.path)
        }

        let candidate = try latestDerivedDataURL(for: projectName)
        return DerivedDataPaths(derivedDataURL: candidate, shouldAppendExtraPaths: true)
    }

    /// Returns the most recently modified DerivedData directory whose name matches the given project prefix.
    /// - Parameter projectName: Project name used to match typical `ProjectName-<hash>` folders inside DerivedData.
    /// - Returns: The URL of the newest DerivedData folder for the project.
    /// - Throws: ``DerivedDataLocatorError.projectNotFound`` when no matching folder exists.
    private func latestDerivedDataURL(for projectName: String) throws -> URL {
        let contents = try fileSystem.contentsOfDirectory(
            at: derivedDataRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let prefix = projectName + "-"
        let candidates: [(url: URL, date: Date)] = contents.compactMap { url in
            guard url.lastPathComponent.hasPrefix(prefix) else { return nil }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true else {
                return nil
            }
            return (url, values.contentModificationDate ?? .distantPast)
        }

        guard let newest = candidates.max(by: { $0.date < $1.date })?.url else {
            throw DerivedDataLocatorError.projectNotFound(projectName)
        }

        return newest
    }
}
