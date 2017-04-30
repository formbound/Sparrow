import Core
import Venice

public enum ResponseBodyStreamError : Error {
    case writeExceedsContentLength
}

final class ResponseBodyStream : OutputStream {
    enum Mode {
        case contentLength(Int)
        case chunkedEncoding
    }
    
    var closed = false
    var bytesRemaining = 0
    
    private let stream: Stream
    private let mode: Mode

    init(_ stream: Stream, mode: Mode) {
        self.stream = stream
        self.mode = mode
        
        if case let .contentLength(contentLength) = mode {
            bytesRemaining = contentLength
        }
    }

    func open(deadline: Deadline) throws {
        closed = false
    }

    func close() {
        closed = true
    }

    func write(_ buffer: UnsafeBufferPointer<Byte>, deadline: Deadline) throws {
        guard !buffer.isEmpty else {
            return
        }

        if closed {
            throw StreamError.closedStream
        }

        switch mode {
        case .contentLength:
            if bytesRemaining - buffer.count < 0 {
                throw ResponseBodyStreamError.writeExceedsContentLength
            }
            
            try stream.write(buffer, deadline: deadline)
            bytesRemaining -= buffer.count
        case .chunkedEncoding:
            try stream.write(String(buffer.count, radix: 16), deadline: deadline)
            try stream.write("\r\n", deadline: deadline)
            try stream.write(buffer, deadline: deadline)
            try stream.write("\r\n", deadline: deadline)
        }
    }

    func flush(deadline: Deadline) throws {
        try stream.flush(deadline: deadline)
    }
}
