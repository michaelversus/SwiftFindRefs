struct PrintBox: @unchecked Sendable {
    // Printing is treated as fire-and-forget logging for parallel tasks.
    let print: (String) -> Void
}
