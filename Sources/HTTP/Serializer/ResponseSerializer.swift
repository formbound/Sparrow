import Core
import Venice

public enum ResponseSerializerError : Error {
    case invalidContentLength
}

public final class ResponseSerializer {
    private let stream: Stream
    private let bufferSize: Int

    public init(stream: Stream, bufferSize: Int = 2048) {
        self.stream = stream
        self.bufferSize = bufferSize
    }

    public func serialize(_ response: OutgoingResponse, timeout: TimeInterval) throws {
        let deadline = timeout.fromNow()
        
        try writeHeaders(for: response, deadline: deadline)
        
        if let contentLength = response.headers["Content-Length"].flatMap({ Int($0) }) {
            try writeBody(for: response, contentLength: contentLength, deadline: deadline)
        } else if response.headers["Transfer-Encoding"] == "chunked" {
            try writeChunkedBody(for: response, deadline: deadline)
        } else {
            try writeBody(for: response, deadline: deadline)
        }
    }
    
    @inline(__always)
    private func writeHeaders(for response: OutgoingResponse, deadline: Deadline) throws {
        var header = response.version.description
        
        header += " "
        header += response.status.statusCode.description
        header += " "
        header += response.status.reasonPhrase
        header += "\r\n"
        
        for (name, value) in response.headers.headers {
            header += name.string
            header += ": "
            header += value
            header += "\r\n"
        }
        
        for cookie in response.cookieHeaders {
            header += "Set-Cookie: "
            header += cookie
            header += "\r\n"
        }
        
        header += "\r\n"
        
        try stream.write(header, deadline: deadline)
    }
    
    @inline(__always)
    private func writeBody(for response: OutgoingResponse, contentLength: Int, deadline: Deadline) throws {
        if contentLength < 0 {
            throw ResponseSerializerError.invalidContentLength
        }
        
        let bodyStream = ResponseBodyStream(stream, mode: .contentLength(contentLength))
        try response.body(bodyStream)
        try stream.flush(deadline: deadline)
        
        if bodyStream.bytesRemaining > 0 {
            throw ResponseSerializerError.invalidContentLength
        }
    }
    
    @inline(__always)
    private func writeChunkedBody(for response: OutgoingResponse, deadline: Deadline) throws {
        let bodyStream = ResponseBodyStream(stream, mode: .chunkedEncoding)
        try response.body(bodyStream)
        try stream.write("0\r\n\r\n", deadline: deadline)
        try stream.flush(deadline: deadline)
    }
    
    @inline(__always)
    private func writeBody(for response: OutgoingResponse, deadline: Deadline) throws {
        try response.body(stream)
        try stream.flush(deadline: deadline)
        stream.close()
    }
}
