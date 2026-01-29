import ArgumentParser
import Foundation
@preconcurrency import IndexStore

/// Entry point for the SwiftFindRefs CLI that provides access to its subcommands.
@main
struct SwiftFindRefs: AsyncParsableCommand {
    /// Command metadata describing the tool summary, supported subcommands, and default behavior.
    static let configuration = CommandConfiguration(
        abstract: "CLI that helps you interact with Xcode's IndexStoreDB.",
        subcommands: [Search.self, RemoveUTI.self, RemoveUI.self],
        defaultSubcommand: RemoveUI.self
    )
}
