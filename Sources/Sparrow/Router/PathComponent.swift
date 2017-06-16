public enum PathComponent {
    case path(String)
    case wildcard
}

extension PathComponent : Hashable {
    public var hashValue: Int {
        switch self {
        case .wildcard:
            return "".hashValue
        case .path(let string):
            return string.hashValue
        }
    }
    
    public static func ==(lhs: PathComponent, rhs: PathComponent) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension PathComponent : ExpressibleByStringLiteral {
    /// :nodoc:
    public init(unicodeScalarLiteral value: String) {
        self = .path(value)
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .path(value)
    }
    
    /// :nodoc:
    public init(stringLiteral value: StringLiteralType) {
        self = .path(value)
    }
}
