import Core
@_exported import HTTP
import TCP
import Venice
import POSIX

public struct HTTPServer {

    /// TCP host of the HTTP server
    public let tcpHost: Host

    /// First responder of the HTTP server
    /// For example, a `Router` is a type of responder.
    /// You can also write your own responders, implementing the `Responder` protocol
    public let responder: HTTPResponder

    /// Error handler of the HTTP server
    /// If the responder throws an error,
    public var errorHandler: (Error) -> Void

    /// Server host
    public let host: String

    /// Server port
    public let port: Int

    /// Server buffer size
    public let bufferSize: Int

    fileprivate let coroutineGroup = CoroutineGroup()

    /// Creates a new HTTP server
    public init(
        host: String = "0.0.0.0",
        port: Int = 8080,
        backlog: Int = 128,
        reusePort: Bool = false,
        bufferSize: Int = 4096,
        responder: HTTPResponder,
        errorHandler: @escaping (Error) -> Void = { error in print("\(error)") }
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
        self.responder = responder
        self.errorHandler = errorHandler
    }

    /// Creates a new HTTPS server
    public init(
        host: String = "0.0.0.0",
        port: Int = 8080,
        backlog: Int = 128,
        reusePort: Bool = false,
        bufferSize: Int = 4096,
        certificatePath: String,
        privateKeyPath: String,
        certificateChainPath: String? = nil,
        responder: HTTPResponder,
        errorHandler: @escaping (Error) -> Void = { error in print("\(error)") }
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
        self.responder = responder
        self.errorHandler = errorHandler
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
                        self.errorHandler(error)
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
                self.errorHandler(error)
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
                    let request = message as! HTTPRequest
                    let response = try responder.respond(to: request)
                    // TODO: Add timeout parameter
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
        var header = ""
        header += "   _____                                          \n"
        header += "  / ___/ ____   ____ _ _____ _____ ____  _      __\n"
        header += "  \\__ \\ / __ \\ / __ `// ___// ___// __ \\| | /| / /\n"
        header += " ___/ // /_/ // /_/ // /   / /   / /_/ /| |/ |/ / \n"
        header += "/____// .___/ \\__,_//_/   /_/    \\____/ |__/|__/  \n"
        header += "     /_/                                          \n"
        header += "--------------------------------------------------\n"
        header += "Started HTTP server at \(host), listening on port \(port)."
        print(header)
    }
}
