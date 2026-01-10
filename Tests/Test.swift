import Foundation
import Testing
@testable import SwiftFindRefs

struct DerivedDataLocatorTests {

    @Test func returnsProvidedDerivedDataPath() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let explicitPath = tempRoot.appendingPathComponent("Explicit", isDirectory: true)
        try FileManager.default.createDirectory(at: explicitPath, withIntermediateDirectories: true)

        let locator = DerivedDataLocator(fileManager: .default, derivedDataRoot: tempRoot)
        let paths = try locator.locateDerivedData(projectName: nil, derivedDataPath: explicitPath.path)

        #expect(paths.derivedDataURL == explicitPath.standardizedFileURL)
        #expect(paths.indexStoreDBURL.path.hasSuffix("Index/DataStore/IndexStoreDB"))
    }

    @Test func picksNewestDerivedDataForProjectName() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let project = "Kaizen"
        let older = tempRoot.appendingPathComponent("\(project)-OLD", isDirectory: true)
        let newer = tempRoot.appendingPathComponent("\(project)-NEW", isDirectory: true)
        try FileManager.default.createDirectory(at: older, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newer, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([
            .modificationDate: Date(timeIntervalSince1970: 100)
        ], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([
            .modificationDate: Date(timeIntervalSince1970: 200)
        ], ofItemAtPath: newer.path)

        let locator = DerivedDataLocator(fileManager: .default, derivedDataRoot: tempRoot)
        let paths = try locator.locateDerivedData(projectName: project, derivedDataPath: nil)

        #expect(paths.derivedDataURL == newer)
    }

    @Test func throwsWhenInputsMissing() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let locator = DerivedDataLocator(fileManager: .default, derivedDataRoot: tempRoot)
        var didThrowMissingInputs = false
        do {
            _ = try locator.locateDerivedData(projectName: nil, derivedDataPath: nil)
        } catch DerivedDataLocatorError.missingInputs {
            didThrowMissingInputs = true
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
        #expect(didThrowMissingInputs)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
