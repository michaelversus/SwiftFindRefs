import Foundation
import Testing
import IndexStore
@testable import SwiftFindRefs

@Suite("SymbolQuery Tests")
struct SymbolQueryTests {
    
    // MARK: - Initialization Tests
    
    @Test("test init with name only sets name and nil kind")
    func test_init_WithNameOnly_setsNameAndNilKind() {
        // Given
        let symbolName = "MyClass"
        
        // When
        let sut = makeSUT(name: symbolName, kindString: nil)
        
        // Then
        #expect(sut.name == symbolName)
        #expect(sut.kind == nil)
    }
    
    @Test("test init with valid kind string sets parsed kind")
    func test_init_WithValidKindString_setsParsedKind() {
        // Given
        let symbolName = "MyClass"
        let kindString = "class"
        
        // When
        let sut = makeSUT(name: symbolName, kindString: kindString)
        
        // Then
        #expect(sut.name == symbolName)
        #expect(sut.kind == .class)
    }
    
    @Test("test init with invalid kind string sets nil kind")
    func test_init_WithInvalidKindString_setsNilKind() {
        // Given
        let symbolName = "MySymbol"
        let kindString = "unknownType"
        
        // When
        let sut = makeSUT(name: symbolName, kindString: kindString)
        
        // Then
        #expect(sut.name == symbolName)
        #expect(sut.kind == nil)
    }
    
    @Test("test init with uppercase kind string parses correctly")
    func test_init_WithUppercaseKindString_parsesCaseInsensitively() {
        // Given
        let symbolName = "MyStruct"
        let kindString = "STRUCT"
        
        // When
        let sut = makeSUT(name: symbolName, kindString: kindString)
        
        // Then
        #expect(sut.kind == .struct)
    }
    
    @Test("test init with mixed case kind string parses correctly")
    func test_init_WithMixedCaseKindString_parsesCaseInsensitively() {
        // Given
        let symbolName = "MyProtocol"
        let kindString = "ProToCoL"
        
        // When
        let sut = makeSUT(name: symbolName, kindString: kindString)
        
        // Then
        #expect(sut.kind == .protocol)
    }
    
    // MARK: - Kind Parsing Tests
    
    @Test("test init parses all supported symbol kinds", arguments: supportedKindMappings())
    func test_init_WithSupportedKind_parsesCorrectly(mapping: (String, SymbolKind)) {
        // Given
        let (kindString, expectedKind) = mapping
        
        // When
        let sut = makeSUT(name: "Symbol", kindString: kindString)
        
        // Then
        #expect(sut.kind == expectedKind)
    }
    
    // MARK: - Matches Tests (using MockSymbol)
    
    @Test("test matches with matching name and nil kind returns true")
    func test_matches_WithMatchingNameAndNilKind_returnsTrue() {
        // Given
        let sut = makeSUT(name: "Selection", kindString: nil)
        let symbol = MockSymbol(kind: .class, name: "Selection")
        
        // When
        let result = sut.matches(symbol)
        
        // Then
        #expect(result == true)
    }
    
    @Test("test matches with different name returns false")
    func test_matches_WithDifferentName_returnsFalse() {
        // Given
        let sut = makeSUT(name: "Selection", kindString: nil)
        let symbol = MockSymbol(kind: .class, name: "OtherClass")
        
        // When
        let result = sut.matches(symbol)
        
        // Then
        #expect(result == false)
    }
    
    @Test("test matches with matching name and kind returns true")
    func test_matches_WithMatchingNameAndKind_returnsTrue() {
        // Given
        let sut = makeSUT(name: "Selection", kindString: "class")
        let symbol = MockSymbol(kind: .class, name: "Selection")
        
        // When
        let result = sut.matches(symbol)
        
        // Then
        #expect(result == true)
    }
    
    @Test("test matches with matching name but different kind returns false")
    func test_matches_WithMatchingNameButDifferentKind_returnsFalse() {
        // Given
        let sut = makeSUT(name: "Selection", kindString: "class")
        let symbol = MockSymbol(kind: .struct, name: "Selection")
        
        // When
        let result = sut.matches(symbol)
        
        // Then
        #expect(result == false)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(name: String, kindString: String?) -> SymbolQuery {
        SymbolQuery(name: name, kindString: kindString)
    }
    
    private static func supportedKindMappings() -> [(String, SymbolKind)] {
        [
            ("class", .class),
            ("struct", .struct),
            ("enum", .enum),
            ("protocol", .protocol),
            ("function", .function),
            ("variable", .variable),
            ("typealias", .typealias),
            ("instancemethod", .instanceMethod),
            ("staticmethod", .staticMethod),
            ("classmethod", .classMethod),
            ("instanceproperty", .instanceProperty),
            ("staticproperty", .staticProperty),
            ("classproperty", .classProperty),
            ("constructor", .constructor),
            ("destructor", .destructor),
            ("field", .field),
            ("enumconstant", .enumConstant),
            ("parameter", .parameter),
            ("module", .module),
            ("extension", .extension),
        ]
    }
}
