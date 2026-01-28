import Testing
@testable import SwiftFindRefs

@Suite("SwiftFindRefs Configuration Tests")
struct SwiftFindRefsTests {
    @Test
    func `Verify CLI version uses VERSION file`() {
        #expect(SwiftFindRefs.configuration.version == SwiftFindRefs.version)
    }
}
