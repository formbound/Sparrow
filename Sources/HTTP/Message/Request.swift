import Core
import Foundation

public struct Request : Message {
    public enum Method {
        case delete
        case get
        case head
        case post
        case put
        case connect
        case options
        case trace
        case patch
        case other(method: String)
    }

    public var method: Method
    public var url: URL
    public var version: Version
    public var headers: Headers
    public var body: Body
    public var storage: [String: Any]

    public init(method: Method, url: URL, version: Version, headers: Headers, body: Body) {
        self.method = method
        self.url = url
        self.version = version
        self.headers = headers
        self.body = body
        self.storage = [:]
    }
}

public protocol RequestInitializable {
    init(request: Request)
}

public protocol RequestRepresentable {
    var request: Request { get }
}

public protocol RequestConvertible : RequestInitializable, RequestRepresentable {}

extension Request : RequestConvertible {
    public init(request: Request) {
        self = request
    }

    public var request: Request {
        return self
    }
}

extension Request {
    public init(method: Method = .get, url: URL = URL(string: "/")!, headers: Headers = [:], body: Body) {
        self.init(
            method: method,
            url: url,
            version: Version(major: 1, minor: 1),
            headers: headers,
            body: body
        )

        switch body {
        case let .buffer(body):
            self.headers["Content-Length"] = body.count.description
        default:
            self.headers["Transfer-Encoding"] = "chunked"
        }
    }

    public init(method: Method = .get, url: URL = URL(string: "/")!, headers: Headers = [:], body: [Byte] = []) {
        self.init(
            method: method,
            url: url,
            headers: headers,
            body: .buffer(body)
        )
    }

    public init(method: Method = .get, url: URL = URL(string: "/")!, headers: Headers = [:], body: DataRepresentable) {
        self.init(
            method: method,
            url: url,
            headers: headers,
            body: .buffer(body.bytes)
        )
    }

    public init(method: Method = .get, url: URL = URL(string: "/")!, headers: Headers = [:], body: Core.InputStream) {
        self.init(
            method: method,
            url: url,
            headers: headers,
            body: .reader(body)
        )
    }

    public init(method: Method = .get, url: URL = URL(string: "/")!, headers: Headers = [:], body: @escaping (Core.OutputStream) throws -> Void) {
        self.init(
            method: method,
            url: url,
            headers: headers,
            body: .writer(body)
        )
    }
}

extension Request {
    public init?(method: Method = .get, url: String, headers: Headers = [:], body: [Byte] = []) {
        guard let url = URL(string: url) else {
            return nil
        }

        self.init(
            method: method,
            url: url,
            headers: headers,
            body: body
        )
    }

    public init?(method: Method = .get, url: String, headers: Headers = [:], body: DataRepresentable) {
        self.init(method: method, url: url, headers: headers, body: body.bytes)
    }

    public init?(method: Method = .get, url: String, headers: Headers = [:], body: Core.InputStream) {
        guard let url = URL(string: url) else {
            return nil
        }

        self.init(
            method: method,
            url: url,
            headers: headers,
            body: body
        )
    }

    public init?(method: Method = .get, url: String, headers: Headers = [:], body: @escaping (Core.OutputStream) throws -> Void) {
        guard let url = URL(string: url) else {
            return nil
        }

        self.init(
            method: method,
            url: url,
            headers: headers,
            body: body
        )
    }
}

//extension Request {
//    public var path: String? {
//        return url.path
//    }
//
//    public var queryItems: [URLQueryItem] {
//        return url.queryItems
//    }
//}

extension Request {
    public var accept: [MediaType] {
        get {
            var acceptedMediaTypes: [MediaType] = []

            if let acceptString = headers["Accept"] {
                let acceptedTypesString = acceptString.components(separatedBy: ",")

                for acceptedTypeString in acceptedTypesString {
                    let acceptedTypeTokens = acceptedTypeString.components(separatedBy: ";")

                    if acceptedTypeTokens.count >= 1 {
                        let mediaTypeString = acceptedTypeTokens[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let acceptedMediaType = try? MediaType(string: mediaTypeString) {
                            acceptedMediaTypes.append(acceptedMediaType)
                        }
                    }
                }
            }

            return acceptedMediaTypes
        }

        set(accept) {
            headers["Accept"] = accept.map({$0.type + "/" + $0.subtype}).joined(separator: ", ")
        }
    }

    public var cookies: Set<Cookie> {
        get {
            return headers["Cookie"].flatMap({Set<Cookie>(cookieHeader: $0)}) ?? []
        }

        set(cookies) {
            headers["Cookie"] = cookies.map({$0.description}).joined(separator: ", ")
        }
    }

    public var authorization: String? {
        get {
            return headers["Authorization"]
        }

        set(authorization) {
            headers["Authorization"] = authorization
        }
    }

    public var host: String? {
        get {
            return headers["Host"]
        }

        set(host) {
            headers["Host"] = host
        }
    }

    public var userAgent: String? {
        get {
            return headers["User-Agent"]
        }

        set(userAgent) {
            headers["User-Agent"] = userAgent
        }
    }
}

extension Request {
    public typealias UpgradeConnection = (Response, Core.Stream) throws -> Void

    public var upgradeConnection: UpgradeConnection? {
        return storage["request-connection-upgrade"] as? UpgradeConnection
    }

    public mutating func upgradeConnection(_ upgrade: @escaping UpgradeConnection)  {
        storage["request-connection-upgrade"] = upgrade
    }
}

extension Request {
    public var pathParameters: [String: String] {
        get {
            return storage["pathParameters"] as? [String: String] ?? [:]
        }

        set(pathParameters) {
            storage["pathParameters"] = pathParameters
        }
    }
}

extension Request : CustomStringConvertible {
    public var requestLineDescription: String {
        return String(describing: method) + " " + url.absoluteString + " HTTP/" + String(describing: version.major) + "." + String(describing: version.minor) + "\n"
    }

    public var description: String {
        return requestLineDescription +
            headers.description
    }
}

extension Request : CustomDebugStringConvertible {
    public var debugDescription: String {
        return description + "\n" + storageDescription
    }
}
