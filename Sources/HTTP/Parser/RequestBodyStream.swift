#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Core
import Venice

public final class RequestBodyStream : InputStream {
    var complete = false
    var bytes = UnsafeBufferPointer<Byte>()
    
    public private(set) var closed = false
    private let parser: RequestParser
    
    public init(parser: RequestParser) {
        self.parser = parser
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
        
        if bytes.isEmpty && !complete {
            try parser.read(deadline: deadline)
        } else if bytes.isEmpty && complete {
            close()
        }
        
        let bytesRead = min(bytes.count, readBuffer.count)
        memcpy(readPointer, bytes.baseAddress, bytesRead)
        
        bytes = UnsafeBufferPointer(
            start: bytes.baseAddress?.advanced(by: bytesRead),
            count: bytes.count - bytesRead
        )
        
        return UnsafeBufferPointer(start: readPointer, count: bytesRead)
    }
}
