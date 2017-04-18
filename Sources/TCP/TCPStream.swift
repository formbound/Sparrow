import Core
import Venice
import IP
import POSIX

public final class TCPStream : Stream {

    private var socket: FileDescriptor?

    public private(set) var ip: IP
    public private(set) var closed: Bool

    internal init(socket: FileDescriptor, ip: IP) {
        self.ip = ip
        self.socket = socket
        self.closed = false
    }

    public init(host: String, port: Int, deadline: Deadline = 1.minute.fromNow()) throws {
        self.ip = try IP(address: host, port: port, deadline: deadline)
        self.socket = nil
        self.closed = true
    }

    public func open(deadline: Deadline) throws {
        let address = ip.address

        guard let socket = try? POSIX.socket(family: address.family, type: .stream, protocol: 0) else {
            throw TCPError.failedToCreateSocket
        }

        try TCP.tune(socket: socket)

        do {
            try POSIX.connect(socket: socket, address: address)
        } catch SystemError.operationNowInProgress {
            do {
                try poll(socket, event: .write, deadline: deadline)
            } catch VeniceError.timeout {
                try TCP.close(socket: socket)
                throw TCPError.connectTimedOut
            }
            try POSIX.checkError(socket: socket)
        } catch {
            try TCP.close(socket: socket)
            throw TCPError.failedToConnectSocket
        }

        self.socket = socket
        self.closed = false
    }

    public func write(_ bytes: UnsafeBufferPointer<UInt8>, deadline: Deadline) throws {
        guard !bytes.isEmpty else {
            return
        }

        let socket = try getSocket()
        try ensureStillOpen()

        loop: while true {
            var remaining: UnsafeBufferPointer<UInt8> = bytes
            do {
                let bytesWritten = try POSIX.send(socket: socket, bytes: remaining.baseAddress!, count: remaining.count, flags: .noSignal)
                guard bytesWritten > 0 else {
                    throw SystemError.other(errorNumber: -1)
                }
                guard bytesWritten < remaining.count else {
                    return
                }

                let remainingCount = remaining.startIndex.advanced(by: bytesWritten).distance(to: remaining.endIndex)
                remaining = UnsafeBufferPointer<UInt8>(start: remaining.baseAddress!.advanced(by: bytesWritten), count: remainingCount)
            } catch {
                switch error {
                case SystemError.resourceTemporarilyUnavailable, SystemError.operationWouldBlock:
                    do {
                        try poll(socket, event: .write, deadline: deadline)
                    } catch VeniceError.timeout {
                        throw StreamError.timeout
                    }
                    continue loop
                case SystemError.connectionResetByPeer, SystemError.brokenPipe:
                    close()
                    throw StreamError.closedStream
                default:
                    throw error
                }
            }
        }
    }
    
    public func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Deadline) throws -> UnsafeBufferPointer<Byte> {
        guard !readBuffer.isEmpty else {
            return UnsafeBufferPointer()
        }

        let socket = try getSocket()
        try ensureStillOpen()

        loop: while true {
            do {

                let bytesRead = try POSIX.receive(socket: socket, bytes: readBuffer)
                guard !bytesRead.isEmpty else {
                    close()
                    throw StreamError.closedStream
                }
                return bytesRead
            } catch {
                switch error {
                case SystemError.resourceTemporarilyUnavailable, SystemError.operationWouldBlock:
                    do {
                        try poll(socket, event: .read, deadline: deadline)
                    } catch VeniceError.timeout {
                        throw StreamError.timeout
                    }
                    continue loop
                default:
                    throw error
                }
            }
        }
    }

    public func flush(deadline: Deadline) throws {
        try getSocket()
        try ensureStillOpen()
    }

    public func close() {
        guard !closed, let socket = try? getSocket() else {
            return
        }

        try? TCP.close(socket: socket)
        self.socket = nil
        self.closed = true
    }

    @discardableResult
    private func getSocket() throws -> FileDescriptor {
        guard let socket = self.socket else {
            throw SystemError.socketIsNotConnected
        }
        return socket
    }

    private func ensureStillOpen() throws {
        if closed {
            throw StreamError.closedStream
        }
    }

    deinit {
        close()
    }
}
