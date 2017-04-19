public enum PathSegment {
    case literal(String)
    case parameter(String)
}

extension PathSegment: CustomDebugStringConvertible {

    public var debugDescription: String {

        switch self {
        case .literal(let literal):
            return literal
        case .parameter(let name):
            return "<\(name)>"
        }
    }

}
