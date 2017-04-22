import Core

public struct Header: RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
}

extension Header: Hashable {
    public var hashValue: Int {
        return rawValue.hashValue
    }
}

extension Header: Equatable {
    public static func == (lhs: Header, rhs: Header) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

public extension Header {

    public static let contentLength = Header(rawValue: "content-length")
    public static let contentType = Header(rawValue: "content-type")

}

extension Header : ExpressibleByStringLiteral {
    public typealias UnicodeScalarLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(rawValue: value)
    }

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(rawValue: value)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

public struct Headers {
    public var headers: [Header: String]

    public init(_ headers: [Header: String]) {
        self.headers = headers
    }
}

extension Headers {
    public static var empty: Headers {
        return Headers()
    }
}

extension Headers : ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Header, String)...) {
        var headers: [Header: String] = [:]

        for (key, value) in elements {
            headers[key] = value
        }

        self.headers = headers
    }
}

extension Headers : Sequence {
    public func makeIterator() -> DictionaryIterator<Header, String> {
        return headers.makeIterator()
    }

    public var count: Int {
        return headers.count
    }

    public var isEmpty: Bool {
        return headers.isEmpty
    }

    public subscript(field: Header) -> String? {
        get {
            return headers[field]
        }

        set(header) {
            headers[field] = header

            if field == "Content-Length" && header != nil && headers["Transfer-Encoding"] == "chunked" {
                headers["Transfer-Encoding"] = nil
            } else if field == "Transfer-Encoding" && header == "chunked" {
                headers["Content-Length"] = nil
            }
        }
    }
}

extension Headers : CustomStringConvertible {
    public var description: String {
        var string = ""

        for (header, value) in headers {
            string += "\(header): \(value)\n"
        }

        return string
    }
}

extension Header: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}

extension Headers : Equatable {}

public func == (lhs: Headers, rhs: Headers) -> Bool {
    return lhs.headers == rhs.headers
}
