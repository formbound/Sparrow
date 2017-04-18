import Core
import POSIX
import IP
import Venice
import Powerline

public enum TCPError : Error {
    case failedToCreateSocket
    case failedToConnectSocket
    case failedToBindSocket
    case failedToListen
    case failedToGetSocketAddress
    case acceptTimedOut
    case connectTimedOut
    case writeTimedOut
    case invalidFileDescriptor
}


public final class TCPHost : Host {
    private let socket: FileDescriptor
    public let ip: IP

    public init(socket: FileDescriptor, ip: IP) {
        self.socket = socket
        self.ip = ip
    }

    public convenience init(ip: IP, backlog: Int, reusePort: Bool) throws {
        var address = ip.address
        guard let socket = try? POSIX.socket(family: address.family, type: .stream, protocol: 0) else {
            throw TCPError.failedToCreateSocket
        }

        try TCP.tune(socket: socket)

        if reusePort {
            try TCP.setReusePort(socket: socket)
        }

        do {
            try POSIX.bind(socket: socket, address: address)
        } catch {
            throw TCPError.failedToBindSocket
        }

        try POSIX.listen(socket: socket, backlog: backlog)

        // If the user requested an ephemeral port, retrieve the port number assigned by the OS now.
        if address.port == 0 {
            do {
                address = try POSIX.getAddress(socket: socket)
            } catch {
                try TCP.close(socket: socket)
                throw TCPError.failedToGetSocketAddress
            }
        }

        let ip = IP(address: address)
        self.init(socket: socket, ip: ip)
    }

    public convenience init(host: String = "0.0.0.0", port: Int = 8080, backlog: Int = 128, reusePort: Bool = false) throws {
        let ip = try IP(address: host, port: port)
        try self.init(ip: ip, backlog: backlog, reusePort: reusePort)
    }

    public convenience init(arguments: [String] = CommandLine.arguments) throws {
        let hostArgument = NamedArgument(name: "host", character: "h", summary: "TCP host address. Defaults to 0.0.0.0", valuePlaceholder: "ip/host")
        let portArgument = NamedArgument(name: "port", character: "p", summary: "TCP host port. Defaults to 8080", valuePlaceholder: "port")
        let backlogArgument = NamedArgument(name: "backlog", character: "b", summary: "TCP backlog. Defaults to 128", valuePlaceholder: "backlog")
        let reusePortArgument = NamedArgument(name: "reuseport", character: "r", summary: "Whether to reuse port. Defaults to false", valuePlaceholder: "true/false")

        let result = try Command(
            name: "sparrow-tcphostrun",
            summary: "Runs TCP hosst",
            namedArguments: [
                hostArgument,
                portArgument,
                backlogArgument,
                reusePortArgument
            ]
            ).run(arguments: arguments)

        try self.init(
            host: try result.value(for: hostArgument) ?? "0.0.0.0",
            port: try result.value(for: portArgument) ?? 8080,
            backlog: try result.value(for: backlogArgument) ?? 128,
            reusePort: try result.value(for: reusePortArgument) ?? false
        )
    }

    public func accept(deadline: Deadline = 1.minute.fromNow()) throws -> Stream {
        loop: while true {
            do {
                // Try to get new connection (non-blocking).
                let (acceptSocket, address) = try POSIX.accept(socket: socket)
                try TCP.tune(socket: acceptSocket)
                let ip = IP(address: address)
                return TCPStream(socket: acceptSocket, ip: ip)
            } catch {
                switch error {
                case SystemError.resourceTemporarilyUnavailable, SystemError.operationWouldBlock:
                    do {
                        // Wait till new connection is available.
                        try poll(socket, event: .read, deadline: deadline)
                        continue loop
                    } catch VeniceError.timeout {
                        throw TCPError.acceptTimedOut
                    }
                default:
                    throw error
                }
            }
        }
    }
}

func close(socket: FileDescriptor) throws {
    Venice.clean(socket)
    try POSIX.close(fileDescriptor: socket)
}

func tune(socket: FileDescriptor) throws {
    do {
        try setNonBlocking(fileDescriptor: socket)
        try setReuseAddress(socket: socket)
        #if os(macOS)
            try setNoSignalOnBrokenPipe(socket: socket)
        #endif
    } catch {
        try TCP.close(socket: socket)
        throw error
    }
}

func setReusePort(socket: FileDescriptor) throws {
    do {
        try POSIX.setReusePort(socket: socket)
    } catch {
        try TCP.close(socket: socket)
        throw error
    }
}
