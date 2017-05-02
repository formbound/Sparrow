import Venice
import Core

public enum ContentParserError : Error {
    case invalidInput
}

public protocol ContentParser {
    init()
    
    @discardableResult func parse(_ buffer: UnsafeBufferPointer<Byte>) throws -> Content?
}

extension ContentParser {
    public func finish() throws -> Content {
        guard let map = try self.parse(UnsafeBufferPointer()) else {
            throw ContentParserError.invalidInput
        }
        return map
    }
    
    public func parse(_ buffer: [Byte]) throws -> Content? {
        return try buffer.withUnsafeBufferPointer({ try parse($0) })
    }
    
    public func parse(_ buffer: DataRepresentable) throws -> Content? {
        return try parse(buffer.bytes)
    }
    
    public static func parse(_ buffer: UnsafeBufferPointer<Byte>) throws -> Content {
        let parser = self.init()
        
        if let map = try parser.parse(buffer) {
            return map
        }
        
        return try parser.finish()
    }
    
    public static func parse(_ buffer: [Byte]) throws -> Content {
        return try buffer.withUnsafeBufferPointer({ try parse($0) })
    }
    
    public static func parse(_ buffer: DataRepresentable) throws -> Content {
        return try parse(buffer.bytes)
    }
    
    public static func parse(_ stream: InputStream, bufferSize: Int = 4096, deadline: Deadline) throws -> Content {
        let parser = self.init()
        let buffer = UnsafeMutableBufferPointer<Byte>(capacity: bufferSize)
        defer { buffer.deallocate(capacity: bufferSize) }
        
        while true {
            let readBuffer = try stream.read(into: buffer, deadline: deadline)
            if let result = try parser.parse(readBuffer) {
                return result
            }
        }
    }
}
