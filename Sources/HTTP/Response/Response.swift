import Core

public struct HTTPResponse: HTTPMessage {
    public var version: Version
    public var status: Status
    public var headers: HTTPHeaders
    public var cookieHeaders: Set<String>
    
    public var body: HTTPBody {
        didSet {
            updateHeadersForNewBody()
        }
    }
    
    public typealias UpgradeConnection = (HTTPRequest, Stream) throws -> Void
    public var upgradeConnection: UpgradeConnection?

    public init(version: Version, status: Status, headers: HTTPHeaders, cookieHeaders: Set<String>, body: HTTPBody) {
        self.version = version
        self.status = status
        self.headers = headers
        self.cookieHeaders = cookieHeaders
        self.body = body

        updateHeadersForNewBody()
    }

    private mutating func updateHeadersForNewBody() {
        switch body {
        case let .data(body):
            headers["Content-Length"] = body.count.description
        default:
            headers["Transfer-Encoding"] = "chunked"
        }
    }
}

extension HTTPResponse {
    public init(status: Status = .ok, headers: HTTPHeaders = [:], body: HTTPBody) {
        self.init(
            version: Version(major: 1, minor: 1),
            status: status,
            headers: headers,
            cookieHeaders: [],
            body: body
        )
    }

    public init(status: Status = .ok, headers: HTTPHeaders = [:], body: [Byte] = []) {
        self.init(
            status: status,
            headers: headers,
            body: .data(body)
        )
    }

    public init(status: Status = .ok, headers: HTTPHeaders = [:], body: DataRepresentable) {
        self.init(status: status, headers: headers, body: body.bytes)
    }

    public init(status: Status = .ok, headers: HTTPHeaders = [:], body: InputStream) {
        self.init(
            status: status,
            headers: headers,
            body: .reader(body)
        )
    }

    public init(status: Status = .ok, headers: HTTPHeaders = [:], body: @escaping (OutputStream) throws -> Void) {
        self.init(
            status: status,
            headers: headers,
            body: .writer(body)
        )
    }
}

extension HTTPResponse {
    public var isInformational: Bool {
        return status.isInformational
    }

    public var isSuccessfull: Bool {
        return status.isSuccessful
    }

    public var isRedirection: Bool {
        return status.isRedirection
    }

    public var isError: Bool {
        return status.isError
    }

    public var isClientError: Bool {
        return status.isClientError
    }

    public var isServerError: Bool {
        return status.isServerError
    }

    public var reasonPhrase: String {
        return status.reasonPhrase
    }
}

extension HTTPResponse {
    public var cookies: Set<AttributedCookie> {
        get {
            var cookies = Set<AttributedCookie>()

            for header in cookieHeaders {
                if let cookie = AttributedCookie(header) {
                    cookies.insert(cookie)
                }
            }

            return cookies
        }

        set(cookies) {
            var headers = Set<String>()

            for cookie in cookies {
                let header = String(describing: cookie)
                headers.insert(header)
            }

            cookieHeaders = headers
        }
    }
}

extension HTTPResponse : CustomStringConvertible {
    public var statusLineDescription: String {
        return "HTTP/" + String(version.major) + "." + String(version.minor) + " " + String(status.statusCode) + " " + reasonPhrase + "\n"
    }

    public var description: String {
        return statusLineDescription + headers.description
    }
}

extension HTTPResponse : CustomDebugStringConvertible {
    public var debugDescription: String {
        return description
    }
}
