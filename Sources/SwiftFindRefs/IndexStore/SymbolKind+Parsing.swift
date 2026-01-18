import IndexStore

extension SymbolKind {
    /// Attempts to convert a textual symbol kind description into the corresponding `SymbolKind` value.
    /// - Parameter type: Case-insensitive textual description such as "class", "function", or "instanceMethod".
    /// - Returns: The matching `SymbolKind` or `nil` when the provided text is unsupported.
    init?(parsing type: String) {
        switch type.lowercased() {
        case "class": self = .class
        case "struct": self = .struct
        case "enum": self = .enum
        case "protocol": self = .protocol
        case "function": self = .function
        case "variable": self = .variable
        case "typealias": self = .typealias
        case "instancemethod": self = .instanceMethod
        case "staticmethod": self = .staticMethod
        case "classmethod": self = .classMethod
        case "instanceproperty": self = .instanceProperty
        case "staticproperty": self = .staticProperty
        case "classproperty": self = .classProperty
        case "constructor": self = .constructor
        case "destructor": self = .destructor
        case "field": self = .field
        case "enumconstant": self = .enumConstant
        case "parameter": self = .parameter
        case "module": self = .module
        case "extension": self = .extension
        default: return nil
        }
    }
}
