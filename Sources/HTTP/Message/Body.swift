import Core
import Venice

public enum Body {
    case data([Byte])
    case reader(InputStream)
    case writer((OutputStream) throws -> Void)
}

extension Body {
    public static var empty: Body {
        return .data([])
    }

    public var isEmpty: Bool {
        switch self {
        case .data(let bytes): return bytes.isEmpty
        default: return false
        }
    }
}

extension Body {
    public var isBuffer: Bool {
        switch self {
        case .data: return true
        default: return false
        }
    }

    public var isReader: Bool {
        switch self {
        case .reader: return true
        default: return false
        }
    }

    public var isWriter: Bool {
        switch self {
        case .writer: return true
        default: return false
        }
    }
}

extension Body {
    public mutating func becomeBytes(deadline: Deadline) throws -> [Byte] {
        switch self {
        case .data(let bytes):
            return bytes
        case .reader(let reader):
            let bytes = try reader.drain(deadline: deadline)
            self = .data(bytes)
            return bytes
        case .writer(let writer):
            let dataStream = DataStream()
            try writer(dataStream)
            let bytes = dataStream.bytes
            self = .data(bytes)
            return bytes
        }
    }

    public mutating func becomeReader() throws -> InputStream {
        switch self {
        case .reader(let reader):
            return reader
        case .data(let bytes):
            let dataStream = DataStream(bytes: bytes)
            self = .reader(dataStream)
            return dataStream
        case .writer(let writer):
            let dataStream = DataStream()
            try writer(dataStream)
            self = .reader(dataStream)
            return dataStream
        }
    }

    public mutating func becomeWriter(deadline: Deadline) throws -> ((OutputStream) throws -> Void) {
        switch self {
        case .data(let bytes):
            let writer: ((OutputStream) throws -> Void) = { writer in
                try writer.write(bytes, deadline: deadline)
                try writer.flush(deadline: deadline)
            }
            self = .writer(writer)
            return writer
        case .reader(let reader):
            let writer: ((OutputStream) throws -> Void) = { writer in
                let bytes = try reader.drain(deadline: deadline)
                try writer.write(bytes, deadline: deadline)
                try writer.flush(deadline: deadline)
            }
            self = .writer(writer)
            return writer
        case .writer(let writer):
            return writer
        }
    }
}

extension Body : Equatable {}

public func == (lhs: Body, rhs: Body) -> Bool {
    switch (lhs, rhs) {
        case let (.data(l), .data(r)) where l == r: return true
        default: return false
    }
}
