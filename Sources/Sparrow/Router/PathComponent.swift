
public struct RouteComponentKey {

    public enum MatchingStrategy {
        case exactly(String)
        case parameter(LosslessStringConvertible.Type)
        case any
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
        case .any:
            return true
        case .parameter(let type):
            return type.init(string) != nil
        }
    }
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


