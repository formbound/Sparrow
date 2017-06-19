
public struct RouteComponentKey {

    public enum MatchingStrategy {
        case exactly(String)
        case wildcard
    }

    public let name: String
    internal let matchingStrategy: MatchingStrategy

    public init(name: String, matchingStrategy: MatchingStrategy) {
        self.name = name
        self.matchingStrategy = matchingStrategy
    }
}

extension RouteComponentKey {
    func matches(string: String) -> Bool {
        switch matchingStrategy {
        case .exactly(let exactString):
            return string == exactString
        case .wildcard:
            return true
        }
    }
}

extension RouteComponentKey {
    static let userId = RouteComponentKey(name: "userId", matchingStrategy: .wildcard)
}

extension RouteComponentKey : Hashable {
    public var hashValue: Int {
        return name.hashValue
    }
    
    public static func ==(lhs: RouteComponentKey, rhs: RouteComponentKey) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension RouteComponentKey : ExpressibleByStringLiteral {
    /// :nodoc:
    public init(unicodeScalarLiteral value: String) {
        self.init(name: value, matchingStrategy: .exactly(value))
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(name: value, matchingStrategy: .exactly(value))
    }
    
    /// :nodoc:
    public init(stringLiteral value: StringLiteralType) {
        self.init(name: value, matchingStrategy: .exactly(value))
    }
}


