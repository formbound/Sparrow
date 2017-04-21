import Core
@_exported import HTTP
import TCP
import Venice
import POSIX

public struct HTTPServer {

    public let tcpHost: Host

    public let router: Router

    public let failure: (Error) -> Void

    public let contentNegotiator: ContentNegotiator

    public let host: String
    public let port: Int
    public let bufferSize: Int

    fileprivate let coroutineGroup = CoroutineGroup()

    public init(
        host: String = "0.0.0.0",
        port: Int = 8080,
        backlog: Int = 128,
        reusePort: Bool = false,
        bufferSize: Int = 4096,
        router: Router,
        contentNegotiator: ContentNegotiator = StandardContentNegotiator(),
        failure: @escaping (Error) -> Void = { error in print("\(error)") }
    ) throws {
        self.tcpHost = try TCPHost(
            host: host,
            port: port,
            backlog: backlog,
            reusePort: reusePort
        )
        self.host = host
        self.port = port
        self.bufferSize = bufferSize
        self.router = router
        self.failure = failure
        self.contentNegotiator = contentNegotiator
    }

    public init(
        host: String = "0.0.0.0",
        port: Int = 8080,
        backlog: Int = 128,
        reusePort: Bool = false,
        bufferSize: Int = 4096,
        certificatePath: String,
        privateKeyPath: String,
        certificateChainPath: String? = nil,
        router: Router,
        contentNegotiator: ContentNegotiator = StandardContentNegotiator(),
        failure: @escaping (Error) -> Void = { error in print("\(error)") }
        ) throws {
        self.tcpHost = try TCPTLSHost(
            host: host,
            port: port,
            backlog: backlog,
            reusePort: reusePort,
            certificatePath: certificatePath,
            privateKeyPath: privateKeyPath,
            certificateChainPath: certificateChainPath
        )
        self.host = host
        self.port = port
        self.bufferSize = bufferSize
        self.router = router
        self.failure = failure
        self.contentNegotiator = contentNegotiator
    }
}

func retry(times: Int, waiting duration: Venice.TimeInterval, work: (Void) throws -> Void) throws {

    var failCount = 0

    var lastError: Error!

    while failCount < times {
        do {
            try work()
        } catch {
            failCount += 1
            lastError = error
            print("Error: \(error)")
            print("Retrying in \(duration) seconds.")

            print("Retrying.")
        }
    }
    throw lastError
}

extension HTTPServer {

    public func start() throws {
        printHeader()
        try retry(times: 10, waiting: 5.seconds) {
            while true {
                let stream = try tcpHost.accept(deadline: .never)

                try coroutineGroup.addCoroutine { // TODO: Evaluate whether coroutine group is good here
                    do {
                        try self.process(stream: stream)
                    } catch {
                        self.failure(error)
                    }
                }
            }
        }
    }

    public func startInBackground() throws {
        try coroutineGroup.addCoroutine {
            do {
                try self.start()
            } catch {
                self.failure(error)
            }
        }
    }

    public func process(stream: Stream) throws {
        let bytes = UnsafeMutableBufferPointer<Byte>(capacity: bufferSize)
        defer { bytes.deallocate(capacity: bufferSize) }

        let parser = MessageParser(mode: .request)
        let serializer = ResponseSerializer(stream: stream, bufferSize: bufferSize)

        while !stream.closed {
            do {
                // TODO: Add timeout parameter
                let bytesRead = try stream.read(into: bytes, deadline: 30.seconds.fromNow())

                for message in try parser.parse(bytesRead) {
                    let request = message as! Request

                    var response: Response

                    if let mediaType = request.contentType {
                        let present = try router.respond(to: RequestContext(request: request))
                        // TODO: Add timeout parameter

                        switch present {
                        case .view(let status, let headers, let view):

                            response = Response(
                                status: status,
                                headers: headers,
                                body: try contentNegotiator.serialize(view: view, mediaType: mediaType, deadline: .never)
                            )

                            break
                        case .response(let r):
                            response = r
                            break
                        }
                    }
                    else {
                        response = Response(status: .unsupportedMediaType)
                    }

                    try serializer.serialize(response, deadline: 5.minutes.fromNow())

                    if let upgrade = response.upgradeConnection {
                        try upgrade(request, stream)
                        stream.close()
                    }

                    if !request.isKeepAlive {
                        stream.close()
                    }
                }
            } catch SystemError.brokenPipe {
                break
            } catch {
                if stream.closed {
                    break
                }

                throw error
            }
        }
    }

    public func printHeader() {
        var header = "\n"
        header += "\n"
        header += "\n"
        header += "                             _____\n"
        header += "     ,.-``-._.-``-.,        /__  /  ___ _      ______\n"
        header += "    |`-._,.-`-.,_.-`|         / /  / _ \\ | /| / / __ \\\n"
        header += "    |   |ˆ-. .-`|   |        / /__/  __/ |/ |/ / /_/ /\n"
        header += "    `-.,|   |   |,.-`       /____/\\___/|__/|__/\\____/ (c)\n"
        header += "        `-.,|,.-`           -----------------------------\n"
        header += "\n"
        header += "================================================================================\n"
        header += "Started HTTP server at \(host), listening on port \(port)."
        print(header)
    }
}
