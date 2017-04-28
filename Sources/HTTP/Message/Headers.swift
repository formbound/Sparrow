import Core

public struct HTTPHeader : RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
}

extension HTTPHeader : Hashable {
    public var hashValue: Int {
        return rawValue.hashValue
    }
}

extension HTTPHeader : Equatable {
    public static func == (lhs: HTTPHeader, rhs: HTTPHeader) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

public extension HTTPHeader {

    public static let contentLength = HTTPHeader(rawValue: "content-length")
    public static let contentType = HTTPHeader(rawValue: "content-type")

}

extension HTTPHeader : ExpressibleByStringLiteral {
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

public struct HTTPHeaders {
    public var headers: [HTTPHeader: String]

    public init(_ headers: [HTTPHeader: String]) {
        self.headers = headers
    }
}

extension HTTPHeaders {
    public static var empty: HTTPHeaders {
        return HTTPHeaders()
    }
}

extension HTTPHeaders : ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (HTTPHeader, String)...) {
        var headers: [HTTPHeader: String] = [:]

        for (key, value) in elements {
            headers[key] = value
        }

        self.headers = headers
    }
}

extension HTTPHeaders : Sequence {
    public func makeIterator() -> DictionaryIterator<HTTPHeader, String> {
        return headers.makeIterator()
    }

    public var count: Int {
        return headers.count
    }

    public var isEmpty: Bool {
        return headers.isEmpty
    }

    public subscript(field: HTTPHeader) -> String? {
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

extension HTTPHeaders : CustomStringConvertible {
    public var description: String {
        var string = ""

        for (header, value) in headers {
            string += "\(header): \(value)\n"
        }

        return string
    }
}

extension HTTPHeader : CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}

extension HTTPHeaders : Equatable {}

public func == (lhs: HTTPHeaders, rhs: HTTPHeaders) -> Bool {
    return lhs.headers == rhs.headers
}
