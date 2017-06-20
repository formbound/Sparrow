public struct RouteComponentKey {
    enum MatchingStrategy {
        case pathComponent(String)
        case parameter(LosslessStringConvertible.Type)
    }

    public static var key = 0
    
    let key: Int
    let matchingStrategy: MatchingStrategy

    fileprivate init(matchingStrategy: MatchingStrategy) {
        defer {
            RouteComponentKey.key += 1
        }
        
        self.key = RouteComponentKey.key
        self.matchingStrategy = matchingStrategy
    }
    
    public static func parameter(_ type: LosslessStringConvertible.Type) -> RouteComponentKey {
        return RouteComponentKey(matchingStrategy: .parameter(type))
    }
}

extension RouteComponentKey : Hashable {
    public var hashValue: Int {
        return key.hashValue
    }
    
    public static func == (lhs: RouteComponentKey, rhs: RouteComponentKey) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension RouteComponentKey : ExpressibleByStringLiteral {
    /// :nodoc:
    public init(unicodeScalarLiteral value: String) {
        self.init(matchingStrategy: .pathComponent(value))
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(matchingStrategy: .pathComponent(value))
    }
    
    /// :nodoc:
    public init(stringLiteral value: StringLiteralType) {
        self.init(matchingStrategy: .pathComponent(value))
    }
}

