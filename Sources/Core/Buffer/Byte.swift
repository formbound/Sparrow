#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public typealias Byte = UInt8

extension Array where Iterator.Element == Byte {

    public init(_ string: String) {
        self = [Byte](string.utf8)
    }

    public init(count: Int, fill: @escaping (UnsafeMutableBufferPointer<Byte>) throws -> Void) throws {
        try self.init(capacity: count) {
            guard count > 0 else {
                return 0
            }
            try fill($0)
            return count
        }
    }


    public init(capacity: Int, fill: @escaping (UnsafeMutableBufferPointer<Byte>) throws -> Int) throws {
        var bytes = [Byte](repeating: 0, count: capacity)
        let usedCapacity = try bytes.withUnsafeMutableBufferPointer { try fill($0) }

        guard usedCapacity > 0 else {
            self = []
            return
        }

        self = [Byte](bytes.prefix(usedCapacity))
    }

    public mutating func append(_ other: UnsafeBufferPointer<Byte>) {
        guard other.count > 0 else {
            return
        }
        append(contentsOf: [Byte](other))
    }

    public mutating func append(_ other: UnsafePointer<Byte>, count: Int) {
        guard count > 0 else {
            return
        }
        append(contentsOf: [Byte](UnsafeBufferPointer(start: other, count: count)))
    }

    public func copyBytes(to pointer: UnsafeMutableBufferPointer<Byte>) {
        guard pointer.count > 0 else {
            return
        }

        precondition(endIndex >= 0)
        precondition(endIndex <= pointer.count, "The pointer is not large enough")

        _ = withUnsafeBufferPointer {
            memcpy(pointer.baseAddress!, $0.baseAddress!, count)
        }

    }

    public func copyBytes(to pointer: UnsafeMutablePointer<Byte>, count: Int) {
        copyBytes(to: UnsafeMutableBufferPointer(start: pointer, count: count))
    }

    public func withUnsafeBytes<Result, ContentType>(body: (UnsafePointer<ContentType>) throws -> Result) rethrows -> Result {
        return try withUnsafeBufferPointer {
            let capacity = count / MemoryLayout<ContentType>.stride
            return try $0.baseAddress!.withMemoryRebound(to: ContentType.self, capacity: capacity) { try body($0) }
        }
    }

    public func hexadecimalString(inGroupsOf characterCount: Int = 0) -> String {
        var string = ""
        for (index, value) in self.enumerated() {
            if characterCount != 0 && index > 0 && index % characterCount == 0 {
                string += " "
            }
            string += (value < 16 ? "0" : "") + String(value, radix: 16)
        }
        return string
    }

    public var hexadecimalDescription: String {
        return hexadecimalString(inGroupsOf: 2)
    }
}

extension UnsafeBufferPointer {
    public init() {
        self.init(start: nil, count: 0)
    }
}

extension UnsafeMutableBufferPointer {
    public init() {
        self.init(start: nil, count: 0)
    }

    public init(capacity: Int) {
        let pointer = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
        self.init(start: pointer, count: capacity)
    }

    public func deallocate(capacity: Int) {
        baseAddress?.deallocate(capacity: capacity)
    }
}

