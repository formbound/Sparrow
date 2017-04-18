import Venice

public enum StreamError : Error {
    case closedStream
    case timeout
}

public protocol InputStream {
    var closed: Bool { get }
    func open(deadline: Deadline) throws
    func close()

    func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Deadline) throws -> UnsafeBufferPointer<Byte>
    func read(upTo byteCount: Int, deadline: Deadline) throws -> [Byte]
    func read(exactly byteCount: Int, deadline: Deadline) throws -> [Byte]
}


extension InputStream {
    public func read(upTo byteCount: Int, deadline: Deadline) throws -> [Byte] {
        guard byteCount > 0 else {
            return .empty
        }

        var bytes = [Byte](repeating: 0, count: byteCount)

        let bytesRead = try bytes.withUnsafeMutableBufferPointer {
            try read(into: $0, deadline: deadline).count
        }

        return [Byte](bytes[0..<bytesRead])
    }

    public func read(exactly byteCount: Int, deadline: Deadline) throws -> [Byte] {
        guard byteCount > 0 else {
            return .empty
        }

        var bytes = [Byte](repeating: 0, count: byteCount)

        try bytes.withUnsafeMutableBufferPointer { pointer in
            var address = pointer.baseAddress!
            var remaining = byteCount
            while remaining > 0 {
                let chunk = try read(into: UnsafeMutableBufferPointer(start: address, count: remaining), deadline: deadline)
                guard chunk.count > 0 else {
                    throw StreamError.closedStream
                }
                address = address.advanced(by: chunk.count)
                remaining -= chunk.count
            }
        }

        return [Byte](bytes)
    }

    /// Drains the `Stream` and returns the contents in a `Buffer`. At the end of this operation the stream will be closed.
    public func drain(deadline: Deadline) throws -> [Byte] {
        var bytes: [Byte] = .empty

        while !self.closed, let chunk = try? self.read(upTo: 2048, deadline: deadline), chunk.count > 0 {
            bytes.append(contentsOf: chunk)
        }

        return bytes
    }
}

public protocol OutputStream {
    var closed: Bool { get }
    func open(deadline: Deadline) throws
    func close()

    func write(_ buffer: UnsafeBufferPointer<Byte>, deadline: Deadline) throws
    func write(_ bytes: [Byte], deadline: Deadline) throws
    func write(_ buffer: DataRepresentable, deadline: Deadline) throws
    func flush(deadline: Deadline) throws
}

extension OutputStream {
    public func write(_ bytes: [Byte], deadline: Deadline) throws {
        guard !bytes.isEmpty else {
            return
        }

        try bytes.withUnsafeBufferPointer {
            try write($0, deadline: deadline)
        }
    }

    public func write(_ converting: DataRepresentable, deadline: Deadline) throws {
        try write(converting.bytes, deadline: deadline)
    }
}

public typealias Stream = InputStream & OutputStream
