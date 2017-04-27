@_exported import HTTP
import Core
import Foundation
import Venice
import TCP

public enum HTTPClientError: Error {
    case invalidURIScheme
    case uriHostRequired
    case brokenConnection
    case invalidUrl
}

public final class HTTPClient {
    fileprivate let secure: Bool

    public let host: String
    public let port: Int

    public let keepAlive: Bool
    public let connectionTimeout: Venice.TimeInterval
    public let requestTimeout: Venice.TimeInterval
    public let bufferSize: Int

    public let certificatePath: String?
    public let privateKeyPath: String?
    public let verifyBundlePath: String?
    public let certificateChainPath: String?

    let addUserAgent: Bool

    var stream: Core.Stream?
    var serializer: RequestSerializer?
    var parser: MessageParser?

    public init(url: URL, bufferSize: Int = 4096, connectionTimeout: Venice.TimeInterval = 3.minutes, requestTimeout: Deadline = 30.seconds, certificatePath: String? = nil, privateKeyPath: String? = nil, certificateChainPath: String? = nil, verifyBundlePath: String? = nil, keepAlive: Bool = true, addUserAgent: Bool = true) throws {
        self.secure = try isSecure(url: url)

        let (host, port) = try getHostPort(url: url)

        self.host = host
        self.port = port

        self.bufferSize = bufferSize
        self.connectionTimeout = connectionTimeout
        self.requestTimeout = requestTimeout

        self.certificatePath = certificatePath
        self.privateKeyPath = privateKeyPath
        self.certificateChainPath = certificateChainPath
        self.verifyBundlePath = verifyBundlePath

        self.addUserAgent = addUserAgent

        self.keepAlive = keepAlive
    }

    public convenience init(url: String, bufferSize: Int = 4096, connectionTimeout: Venice.TimeInterval = 3.minutes, requestTimeout: Venice.TimeInterval = 30.seconds, certificatePath: String? = nil, privateKeyPath: String? = nil, verifyBundlePath: String? = nil, keepAlive: Bool = true, addUserAgent: Bool = true) throws {
        guard let url = URL(string: url) else {
            throw HTTPClientError.invalidUrl
        }

        try self.init(
            url: url,
            bufferSize: bufferSize,
            connectionTimeout: connectionTimeout,
            requestTimeout: requestTimeout,
            certificatePath: certificatePath,
            privateKeyPath: privateKeyPath,
            verifyBundlePath: verifyBundlePath,
            keepAlive: keepAlive,
            addUserAgent: addUserAgent
        )
    }
}

extension HTTPClient: HTTPResponder {

    public func respond(to request: HTTPRequest) throws -> HTTPResponse {
        return try self.request(request)
    }

    public func request(_ request: HTTPRequest) throws -> HTTPResponse {
        var request = request
        addHeaders(to: &request)

        let stream = try getStream()
        let serializer = getSerializer(stream: stream)
        let parser = getParser()

        self.stream = stream
        self.serializer = serializer
        self.parser = parser

        let requestDeadline = now() + requestTimeout

        do {
            // TODO: Add deadline to serializer
            // TODO: Deal with multiple responses

            // send the request down the stream
            try serializer.serialize(request, deadline: requestDeadline)

            while !stream.closed {
                let chunk = try stream.read(upTo: bufferSize, deadline: requestDeadline)

                guard let message = try parser.parse(chunk).first else {
                    // if theres no message, loop and read more
                    continue
                }

                // we made the parser in response mode, so this is "safe"
                let response = message as! HTTPResponse

                if let upgrade = request.upgradeConnection {
                    // hand off the stream to something else, for
                    // example this turn into a websocket connection
                    try upgrade(response, stream)
                }

                // if the stream is not keepalive,
                //   the transaction is finished
                // if the response is an error,
                //   the transaction is finished (even if keepalive)
                // if the stream is keepalive,
                //   it can be reused for more messages
                if response.isError || !keepAlive {
                    self.stream = nil
                    stream.close()
                }

                return response
            }

            // stream closed before we got a response out of it
            throw StreamError.closedStream

        } catch StreamError.closedStream {
            defer {
                self.stream = nil
            }

            // rethrow error if request requires connect upgrade
            guard request.upgradeConnection == nil else {
                throw StreamError.closedStream
            }

            // try and finish the parsing
            guard let message = try parser.finish().first else {
                throw StreamError.closedStream
            }

            return message as! HTTPResponse
        } catch let error as StreamError {
            self.stream = nil
            throw error
        }
    }

    private func addHeaders(to request: inout HTTPRequest) {
        request.host = request.host ?? "\(host):\(port)"

        if addUserAgent {
            request.userAgent = request.userAgent ?? "Zewo"
        }

        if !keepAlive {
            request.connection = request.connection ?? "close"
        }
    }

    private func getStream() throws -> Core.Stream {
        if let stream = self.stream {
            return stream
        }

        let stream: Core.Stream

        if secure {
            stream = try TCPTLSStream(
                host: host,
                port: port,
                certificatePath: certificatePath,
                privateKeyPath: privateKeyPath,
                certificateChainPath: certificateChainPath,
                verifyBundle: verifyBundlePath,
                sniHostname: host,
                deadline: now() + connectionTimeout
            )
        } else {
            stream = try TCPStream(
                host: host,
                port: port,
                deadline: now() + connectionTimeout
            )
        }

        try stream.open(deadline: now() + connectionTimeout)
        return stream
    }

    private func getSerializer(stream: Core.Stream) -> RequestSerializer {
        if let serializer = serializer {
            return serializer
        }
        return RequestSerializer(stream: stream)
    }

    private func getParser() -> MessageParser {
        if let parser = self.parser {
            return parser
        }
        return MessageParser(mode: .response)
    }
}

extension HTTPClient {
    public func get(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .get, url: url, headers: headers, body: body)
    }

    public func get(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .get, url: url, headers: headers, body: body.bytes)
    }

    public func head(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .head, url: url, headers: headers, body: body)
    }

    public func head(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .head, url: url, headers: headers, body: body.bytes)
    }

    public func post(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .post, url: url, headers: headers, body: body)
    }

    public func post(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .post, url: url, headers: headers, body: body.bytes)
    }

    public func put(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .put, url: url, headers: headers, body: body)
    }

    public func put(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .put, url: url, headers: headers, body: body.bytes)
    }

    public func patch(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .patch, url: url, headers: headers, body: body)
    }

    public func patch(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .patch, url: url, headers: headers, body: body.bytes)
    }

    public func delete(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .delete, url: url, headers: headers, body: body)
    }

    public func delete(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .delete, url: url, headers: headers, body: body.bytes)
    }

    public func options(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .options, url: url, headers: headers, body: body)
    }

    public func options(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .options, url: url, headers: headers, body: body.bytes)
    }

    private func request(method: HTTPRequest.Method, url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        guard let url = URL(string: url) else {
            throw HTTPClientError.invalidUrl
        }
        let req = HTTPRequest(method: method, url: url, headers: headers, body: body)
        return try request(req)
    }
}

extension HTTPClient {
    public static func get(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .get, url: url, headers: headers, body: body)
    }

    public static func get(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .get, url: url, headers: headers, body: body.bytes)
    }

    public static func head(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .head, url: url, headers: headers, body: body)
    }

    public static func head(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .head, url: url, headers: headers, body: body.bytes)
    }

    public static func post(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .post, url: url, headers: headers, body: body)
    }

    public static func post(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .post, url: url, headers: headers, body: body.bytes)
    }

    public static func put(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .put, url: url, headers: headers, body: body)
    }

    public static func put(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .put, url: url, headers: headers, body: body.bytes)
    }

    public static func patch(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .patch, url: url, headers: headers, body: body)
    }

    public static func patch(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .patch, url: url, headers: headers, body: body.bytes)
    }

    public static func delete(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .delete, url: url, headers: headers, body: body)
    }

    public static func delete(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .delete, url: url, headers: headers, body: body.bytes)
    }

    public static func options(_ url: String, headers: HTTPHeaders = [:], body: [Byte] = []) throws -> HTTPResponse {
        return try request(method: .options, url: url, headers: headers, body: body)
    }

    public static func options(_ url: String, headers: HTTPHeaders = [:], body: DataRepresentable) throws -> HTTPResponse {
        return try request(method: .options, url: url, headers: headers, body: body.bytes)
    }

    fileprivate static func request(method: HTTPRequest.Method, url: String, headers: HTTPHeaders = [:], body: [Byte]) throws -> HTTPResponse {
        guard let clientUrl = URL(string: url) else {
            throw HTTPClientError.invalidUrl
        }

        let client = try getCachedClient(url: clientUrl)

        let request = HTTPRequest(method: method, url: clientUrl, headers: headers, body: body)
        return try client.request(request)
    }

    private static func getCachedClient(url: URL) throws -> HTTPClient {
        let (host, port) = try getHostPort(url: url)
        let hash = host.hashValue ^ port.hashValue

        guard let client = cachedClients[hash] else {
            let client = try HTTPClient(url: url)
            cachedClients[hash] = client
            return client
        }

        return client
    }
}

fileprivate func isSecure(url: URL) throws -> Bool {
    let scheme = url.scheme ?? "http"

    switch scheme {
    case "http": return false
    case "https": return true
    default: throw HTTPClientError.invalidURIScheme
    }
}

fileprivate func getHostPort(url: URL) throws -> (String, Int) {
    let scheme = url.scheme ?? "http"

    guard let host = url.host else {
        throw HTTPClientError.uriHostRequired
    }

    let port: Int

    switch scheme {
    case "http": port = url.port ?? 80
    case "https": port = url.port ?? 443
    default: throw HTTPClientError.invalidURIScheme
    }

    return (host, port)
}

private var cachedClients: [Int: HTTPClient] = [:]
