import Foundation

/// Represents the resolved DerivedData location and how it should be consumed.
struct DerivedDataPaths {
    /// Absolute URL to the root DerivedData directory that should be used.
    let derivedDataURL: URL
    /// Indicates whether helper subpaths should be appended when deriving indexes.
    let shouldAppendExtraPaths: Bool

    /// Points to the IndexStore database, automatically appending the Xcode-specific subpath when needed.
    var indexStoreDBURL: URL {
        shouldAppendExtraPaths ? derivedDataURL
            .appendingPathComponent("Index.noindex", isDirectory: true)
            .appendingPathComponent("DataStore", isDirectory: true)
            .appendingPathComponent("IndexStoreDB", isDirectory: true)
        : derivedDataURL
    }
}
