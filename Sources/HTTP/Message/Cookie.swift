public struct HTTPCookie: HTTPCookieProtocol {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension HTTPCookie : Hashable {
    public var hashValue: Int {
        return name.hashValue
    }
}

extension HTTPCookie : Equatable {}

public func == (lhs: HTTPCookie, rhs: HTTPCookie) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension HTTPCookie : CustomStringConvertible {
    public var description: String {
        return "\(name)=\(value)"
    }
}

public protocol HTTPCookieProtocol {
    init(name: String, value: String)
}

extension Set where Element : HTTPCookieProtocol {
    public init?(cookieHeader: String) {
        var cookies = Set<Element>()
        let tokens = cookieHeader.components(separatedBy: ";")

        for token in tokens {
            let cookieTokens = token.components(separatedBy: "=")

            guard cookieTokens.count == 2 else {
                return nil
            }

            cookies.insert(Element(name: cookieTokens[0].trimmingCharacters(in: .whitespacesAndNewlines), value: cookieTokens[1].trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        self = cookies
    }
}
