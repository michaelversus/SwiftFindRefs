import ArgumentParser
import Foundation
@preconcurrency import IndexStore

@main
struct SwiftFindRefs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "CLI that helps you interact with Xcode's IndexStoreDB.",
        subcommands: [Search.self, RemoveUTI.self],
        defaultSubcommand: Search.self
    )
}
