import Core
import Venice
import POSIX

public final class TCPStream : DuplexStream {
    private var socket: FileDescriptor?

    public private(set) var ip: IP

    internal init(socket: FileDescriptor, ip: IP) {
        self.ip = ip
        self.socket = socket
    }

    public init(host: String, port: Int, deadline: Deadline) throws {
        self.ip = try IP(address: host, port: port, deadline: deadline)
        self.socket = nil
    }
    
    deinit {
        close()
    }

    public func open(deadline: Deadline) throws {
        let address = ip.address

        guard let socket = try? POSIX.socket(family: address.family, type: .stream, protocol: 0) else {
            throw TCPError.failedToCreateSocket
        }

        try tune(socket: socket)

        do {
            try POSIX.connect(socket: socket, address: address)
        } catch SystemError.operationNowInProgress {
            do {
                try poll(socket, event: .write, deadline: deadline)
            } catch VeniceError.timeout {
                try Networking.close(socket: socket)
                throw TCPError.connectTimedOut
            }
            try POSIX.checkError(socket: socket)
        } catch {
            try Networking.close(socket: socket)
            throw TCPError.failedToConnectSocket
        }

        self.socket = socket
    }

    public func write(_ bytes: UnsafeRawBufferPointer, deadline: Deadline) throws {
        guard !bytes.isEmpty else {
            return
        }

        let socket = try getSocket()

        loop: while true {
            var remaining: UnsafeRawBufferPointer = bytes
            
            do {
                let bytesWritten = try POSIX.send(
                    socket: socket,
                    bytes: remaining,
                    flags: .noSignal
                )
                
                guard bytesWritten < remaining.count else {
                    return
                }
        
                let remainingCount = remaining.startIndex
                    .advanced(by: bytesWritten)
                    .distance(to: remaining.endIndex)
                
                remaining = UnsafeRawBufferPointer(
                    start: remaining.baseAddress!.advanced(by: bytesWritten),
                    count: remainingCount
                )
                
                continue loop
            } catch {
                switch error {
                case SystemError.resourceTemporarilyUnavailable, SystemError.operationWouldBlock:
                    try poll(socket, event: .write, deadline: deadline)
                    continue loop
                case SystemError.connectionResetByPeer, SystemError.brokenPipe:
                    close()
                    throw error
                default:
                    throw error
                }
            }
        }
    }

    public func read(
        into buffer: UnsafeMutableRawBufferPointer,
        deadline: Deadline
    ) throws -> UnsafeRawBufferPointer {
        guard !buffer.isEmpty, let baseAddress = buffer.baseAddress else {
            return UnsafeRawBufferPointer(start: nil, count: 0)
        }

        let socket = try getSocket()

        loop: while true {
            do {
                let bytesRead = try POSIX.receive(socket: socket, buffer: buffer)
                
                guard bytesRead != 0 else {
                    close()
                    throw SystemError.connectionResetByPeer
                }
                
                return UnsafeRawBufferPointer(start: baseAddress, count: bytesRead)
            } catch {
                switch error {
                case SystemError.resourceTemporarilyUnavailable, SystemError.operationWouldBlock:
                    try poll(socket, event: .read, deadline: deadline)
                    continue loop
                default:
                    throw error
                }
            }
        }
    }

    public func flush(deadline: Deadline) throws {
        try getSocket()
    }

    public func close() {
        guard let socket = try? getSocket() else {
            return
        }

        try? Networking.close(socket: socket)
        self.socket = nil
    }

    @discardableResult
    private func getSocket() throws -> FileDescriptor {
        guard let socket = self.socket else {
            throw SystemError.socketIsNotConnected
        }
        
        return socket
    }
}
