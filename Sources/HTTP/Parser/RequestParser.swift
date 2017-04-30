import CHTTPParser
import Core
import Foundation
import Venice
import POSIX

public typealias RequestParserError = http_errno

extension RequestParserError : Error, CustomStringConvertible {
    public var description: String {
        return String(cString: http_errno_description(self))
    }
}

extension Method {
    internal init(code: http_method) {
        switch code {
        case HTTP_DELETE: self = .delete
        case HTTP_GET: self = .get
        case HTTP_HEAD: self = .head
        case HTTP_POST: self = .post
        case HTTP_PUT: self = .put
        case HTTP_CONNECT: self = .connect
        case HTTP_OPTIONS: self = .options
        case HTTP_TRACE: self = .trace
        case HTTP_COPY: self = .other(method: "COPY")
        case HTTP_LOCK: self = .other(method: "LOCK")
        case HTTP_MKCOL: self = .other(method: "MKCOL")
        case HTTP_MOVE: self = .other(method: "MOVE")
        case HTTP_PROPFIND: self = .other(method: "PROPFIND")
        case HTTP_PROPPATCH: self = .other(method: "PROPPATCH")
        case HTTP_SEARCH: self = .other(method: "SEARCH")
        case HTTP_UNLOCK: self = .other(method: "UNLOCK")
        case HTTP_BIND: self = .other(method: "BIND")
        case HTTP_REBIND: self = .other(method: "REBIND")
        case HTTP_UNBIND: self = .other(method: "UNBIND")
        case HTTP_ACL: self = .other(method: "ACL")
        case HTTP_REPORT: self = .other(method: "REPORT")
        case HTTP_MKACTIVITY: self = .other(method: "MKACTIVITY")
        case HTTP_CHECKOUT: self = .other(method: "CHECKOUT")
        case HTTP_MERGE: self = .other(method: "MERGE")
        case HTTP_MSEARCH: self = .other(method: "M-SEARCH")
        case HTTP_NOTIFY: self = .other(method: "NOTIFY")
        case HTTP_SUBSCRIBE: self = .other(method: "SUBSCRIBE")
        case HTTP_UNSUBSCRIBE: self = .other(method: "UNSUBSCRIBE")
        case HTTP_PATCH: self = .patch
        case HTTP_PURGE: self = .other(method: "PURGE")
        case HTTP_MKCALENDAR: self = .other(method: "MKCALENDAR")
        case HTTP_LINK: self = .other(method: "LINK")
        case HTTP_UNLINK: self = .other(method: "UNLINK")
        default: self = .other(method: "UNKNOWN")
        }
    }
}


public final class RequestParser {
    fileprivate enum State: Int {
        case ready = 1
        case messageBegin = 2
        case url = 3
        case headerField = 5
        case headerValue = 6
        case headersComplete = 7
        case body = 8
        case messageComplete = 9
    }
    
    fileprivate class Context {
        var url: URL?
        var headers: Headers = [:]
        
        weak var bodyStream: RequestBodyStream?
        
        var currentHeaderField: HeaderField?
        
        func addValueForCurrentHeaderField(_ value: String) {
            let key = currentHeaderField!
            
            if let existing = headers[key] {
                headers[key] = existing + ", " + value
            } else {
                headers[key] = value
            }
        }
    }
    
    fileprivate let stream: Core.InputStream
    private let bufferSize: Int
    private let buffer: UnsafeMutableBufferPointer<Byte>
    
    public var parser: http_parser
    public var parserSettings: http_parser_settings
    
    private var state: State = .ready
    private var context = Context()
    private var bytes: [Byte] = []
    
    private var requests: [IncomingRequest] = []
    
    private var body: (IncomingRequest) throws -> Void = { _ in }
    
    public init(stream: Core.InputStream, bufferSize: Int = 2048) {
        self.stream = stream
        self.bufferSize = bufferSize
        self.buffer = UnsafeMutableBufferPointer<Byte>(capacity: bufferSize)
        
        var parser = http_parser()
        
        http_parser_init(&parser, HTTP_REQUEST)
        
        
        var parserSettings = http_parser_settings()
        http_parser_settings_init(&parserSettings)
        
        parserSettings.on_message_begin = http_parser_on_message_begin
        parserSettings.on_url = http_parser_on_url
        parserSettings.on_header_field = http_parser_on_header_field
        parserSettings.on_header_value = http_parser_on_header_value
        parserSettings.on_headers_complete = http_parser_on_headers_complete
        parserSettings.on_body = http_parser_on_body
        parserSettings.on_message_complete = http_parser_on_message_complete
        
        self.parser = parser
        self.parserSettings = parserSettings
        
        self.parser.data = Unmanaged.passUnretained(self).toOpaque()
    }
    
    deinit {
        buffer.deallocate(capacity: bufferSize)
    }
    
    public func parse(timeout: Venice.TimeInterval, _ body: @escaping (IncomingRequest) throws -> Void) throws {
        self.body = body
        
        while !stream.closed {
            do {
                try read(deadline: timeout.fromNow())
            } catch SystemError.brokenPipe {
                break
            } catch StreamError.timeout {
                if stream.closed {
                    break
                }
                
                continue
            }  catch {
                if stream.closed {
                    break
                }
                
                throw error
            }
        }
    }
    
    func read(deadline: Deadline) throws {
        let read = try stream.read(into: buffer, deadline: deadline)
        
        if read.isEmpty {
            stream.close()
        }
        
        let requests = try parse(read)
        
        for request in requests {
            try body(request)
        }
    }
    
    private func parse(_ buffer: UnsafeBufferPointer<Byte>) throws -> [IncomingRequest] {
        let final = buffer.isEmpty
        let needsMessage: Bool
        
        switch state {
        case .ready, .messageComplete:
            needsMessage = false
        default:
            needsMessage = final
        }
        
        let processedCount: Int
        
        if final {
            processedCount = http_parser_execute(&parser, &parserSettings, nil, 0)
        } else {
            processedCount = buffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: buffer.count) {
                return http_parser_execute(&self.parser, &self.parserSettings, $0, buffer.count)
            }
        }
        
        guard processedCount == buffer.count else {
            throw RequestParserError(parser.http_errno)
        }
        
        let parsed = requests
        requests = []
        
        guard !parsed.isEmpty || !needsMessage else {
            throw RequestParserError(HPE_INVALID_EOF_STATE.rawValue)
        }
        
        return parsed
    }
    
    fileprivate func processOnMessageBegin() -> Int32 {
        return process(state: .messageBegin)
    }
    
    fileprivate func processOnURL(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        return process(state: .url, data: UnsafeBufferPointer<Int8>(start: data, count: length))
    }
    
    fileprivate func processOnHeaderField(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        return process(state: .headerField, data: UnsafeBufferPointer<Int8>(start: data, count: length))
    }
    
    fileprivate func processOnHeaderValue(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        return process(state: .headerValue, data: UnsafeBufferPointer<Int8>(start: data, count: length))
    }
    
    fileprivate func processOnHeadersComplete() -> Int32 {
        return process(state: .headersComplete)
    }
    
    fileprivate func processOnBody(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        return process(state: .body, data: UnsafeBufferPointer<Int8>(start: data, count: length))
    }
    
    fileprivate func processOnMessageComplete() -> Int32 {
        return process(state: .messageComplete)
    }
    
    fileprivate func process(state newState: State, data: UnsafeBufferPointer<Int8>? = nil) -> Int32 {
        if state != newState {
            switch state {
            case .ready, .messageBegin, .messageComplete:
                break
            case .url:
                bytes.append(0)
                
                let string = bytes.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<UInt8>) -> String in
                    return String(cString: ptr.baseAddress!)
                }
                
                context.url = URL(string: string)!
            case .headerField:
                bytes.append(0)
                
                let string = bytes.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<UInt8>) -> String in
                    return String(cString: ptr.baseAddress!)
                }
                
                context.currentHeaderField = HeaderField(string)
            case .headerValue:
                bytes.append(0)
                
                let string = bytes.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<UInt8>) -> String in
                    return String(cString: ptr.baseAddress!)
                }
                
                context.addValueForCurrentHeaderField(string)
            case .headersComplete:
                context.currentHeaderField = nil
                let bodyStream = RequestBodyStream(parser: self)
                
                let request = IncomingRequest(
                    method: Method(code: http_method(rawValue: parser.method)),
                    url: context.url!,
                    version: Version(major: Int(parser.http_major), minor: Int(parser.http_minor)),
                    headers: context.headers,
                    body: bodyStream
                )
                
                context.bodyStream = bodyStream
                requests.append(request)
            case .body:
                break
            }
            
            bytes = []
            state = newState
            
            if state == .messageComplete {
                context.bodyStream!.complete = true
                context = Context()
            }
        }
        
        guard let data = data, data.count > 0 else {
            return 0
        }
        
        switch state {
        case .body:
            data.baseAddress!.withMemoryRebound(to: Byte.self, capacity: data.count) { address in
                context.bodyStream!.bytes = UnsafeBufferPointer(start: address, count: data.count)
            }
        default:
            data.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: data.count) { ptr in
                for i in 0 ..< data.count {
                    bytes.append(ptr[i])
                }
            }
        }
        
        return 0
    }
}

private func http_parser_on_message_begin(ctx: UnsafeMutablePointer<http_parser>?) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnMessageBegin()
}

private func http_parser_on_url(ctx: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnURL(data: data!, length: length)
}

private func http_parser_on_header_field(ctx: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnHeaderField(data: data!, length: length)
}

private func http_parser_on_header_value(ctx: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnHeaderValue(data: data!, length: length)
}

private func http_parser_on_headers_complete(ctx: UnsafeMutablePointer<http_parser>?) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnHeadersComplete()
}

private func http_parser_on_body(ctx: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnBody(data: data!, length: length)
}

private func http_parser_on_message_complete(ctx: UnsafeMutablePointer<http_parser>?) -> Int32 {
    let ref = Unmanaged<RequestParser>.fromOpaque(ctx!.pointee.data).takeUnretainedValue()
    return ref.processOnMessageComplete()
}
