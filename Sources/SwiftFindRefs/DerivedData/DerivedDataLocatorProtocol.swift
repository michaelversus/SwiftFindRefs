import Foundation

/// Provides an abstraction for finding the correct DerivedData directory for a given project.
protocol DerivedDataLocatorProtocol {
    /// Locates the DerivedData directory either from an explicit path or by inferring it from the project name.
    /// - Parameters:
    ///   - projectName: The name of the Xcode project whose DerivedData should be searched.
    ///   - derivedDataPath: An optional explicit DerivedData path that takes precedence when provided.
    /// - Returns: Paths describing the resolved DerivedData location and whether helper paths should be appended.
    /// - Throws: ``DerivedDataLocatorError`` when the provided inputs are invalid or the DerivedData directory cannot be found.
    func locateDerivedData(
        projectName: String?,
        derivedDataPath: String?
    ) throws -> DerivedDataPaths
}
