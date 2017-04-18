import Venice

public final class DataStream : Stream {
    public private(set) var bytes: [Byte]
    public private(set) var closed = false

    public init(bytes: [Byte] = .empty) {
        self.bytes = bytes
    }

    public convenience init(bytes dataRepresentable: DataRepresentable) {
        self.init(bytes: dataRepresentable.bytes)
    }

    public func open(deadline: Deadline) throws {
        closed = false
    }

    public func close() {
        closed = true
    }

    public func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Deadline) throws -> UnsafeBufferPointer<Byte> {
        guard !closed, let readPointer = readBuffer.baseAddress else {
            return UnsafeBufferPointer()
        }

        let bytesRead = min(bytes.count, readBuffer.count)
        bytes.copyBytes(to: readPointer, count: bytesRead)
        bytes = Array(bytes.suffix(from: bytesRead))

        return UnsafeBufferPointer(start: readPointer, count: bytesRead)
    }

    public func write(_ writeBuffer: UnsafeBufferPointer<UInt8>, deadline: Deadline) {
        bytes.append(writeBuffer)
    }

    public func flush(deadline: Deadline) throws {}
}
