import Core
import OpenSSL
import Venice

public struct TCPTLSStream : Stream {
    public let tcpStream: TCPStream
    public let sslStream: SSLStream

    public init(host: String, port: Int, certificatePath: String? = nil, privateKeyPath: String? = nil, certificateChainPath: String? = nil, verifyBundle: String? = nil, sniHostname: String? = nil, deadline: Deadline) throws {
        self.tcpStream = try TCPStream(host: host, port: port, deadline: deadline)
        let context = try Context(
            certificatePath: certificatePath,
            privateKeyPath: privateKeyPath,
            certificateChainPath: certificateChainPath,
            verifyBundle: verifyBundle,
            sniHostname: sniHostname
        )
        self.sslStream = try SSLStream(context: context, rawStream: tcpStream)
    }

    public func open(deadline: Deadline) throws {
        try tcpStream.open(deadline: deadline)
        try sslStream.open(deadline: deadline)
    }

    public var closed: Bool {
        return sslStream.closed
    }

    public func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Deadline) throws -> UnsafeBufferPointer<Byte> {
        return try sslStream.read(into: readBuffer, deadline: deadline)
    }
    
    public func write(_ buffer: UnsafeBufferPointer<Byte>, deadline: Deadline) throws {
        try sslStream.write(buffer, deadline: deadline)
    }

    public func flush(deadline: Deadline) throws {
        try sslStream.flush(deadline: deadline)
    }

    public func close() {
        sslStream.close()
    }
}
