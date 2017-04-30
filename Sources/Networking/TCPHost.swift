import Core
import POSIX
import Venice

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

        try tune(socket: socket)

        if reusePort {
            try setReusePort(socket: socket)
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
                try close(socket: socket)
                throw TCPError.failedToGetSocketAddress
            }
        }

        let ip = IP(address: address)
        self.init(socket: socket, ip: ip)
    }

    public convenience init(
        host: String = "0.0.0.0",
        port: Int = 8080,
        backlog: Int = 128,
        reusePort: Bool = false,
        deadline: Deadline
    ) throws {
        let ip = try IP(address: host, port: port, deadline: deadline)
        try self.init(ip: ip, backlog: backlog, reusePort: reusePort)
    }

    public func accept(deadline: Deadline) throws -> Stream {
        loop: while true {
            do {
                // Try to get new connection (non-blocking).
                let (acceptSocket, address) = try POSIX.accept(socket: socket)
                try tune(socket: acceptSocket)
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
        try close(socket: socket)
        throw error
    }
}

func setReusePort(socket: FileDescriptor) throws {
    do {
        try POSIX.setReusePort(socket: socket)
    } catch {
        try close(socket: socket)
        throw error
    }
}
