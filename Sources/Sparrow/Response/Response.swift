import Core
import HTTP
import Venice

public protocol ResponseRepresentable {
    var response: Response { get }
}

public enum ResponseError : Error {
    case unserializedBody
}

public enum ResponseBody {
    case content(Content)
    case body(HTTPBody)
}

extension ResponseBody : CustomStringConvertible {
    public var description: String {
        switch self {
        case let .content(content):
            return content.description
        case let .body(body):
            switch body {
            case let .data(data):
                return data.description
            default:
                return ""
            }
        }
    }
}

public class Response {
    public var status: HTTPResponse.Status
    public var headers: HTTPHeaders
    public var body: ResponseBody
    
    public init(status: HTTPResponse.Status = .ok, headers: HTTPHeaders = [:]) {
        self.status = status
        self.headers = headers
        self.body = .body(.empty)
    }
    
    public init(status: HTTPResponse.Status = .ok, headers: HTTPHeaders = [:], content: Content) {
        self.status = status
        self.headers = headers
        self.body = .content(content)
    }

    public convenience init(status: HTTPResponse.Status = .ok, headers: HTTPHeaders = [:], content: ContentRepresentable) {
        self.init(
            status: status,
            headers: headers,
            content: content.content
        )
    }
}

extension Response : ResponseRepresentable {
    public var response: Response {
        return self
    }
}

extension Response {
    public var httpResponse: HTTPResponse {
        switch body {
        case let .body(body):
            return HTTPResponse(status: status, headers: headers, body: body)
        case let .content(content):
            return HTTPResponse(status: status, headers: headers) { stream in
                try JSONSerializer.serialize(content, stream: stream, deadline: 1.minute)
            }
        }
    }
}

extension Response {
    public var contentType: MediaType? {
        get {
            return headers["Content-Type"].flatMap({try? MediaType(string: $0)})
        }
        
        set(contentType) {
            headers["Content-Type"] = contentType?.description
        }
    }
    
    public var contentLength: Int? {
        get {
            return headers["Content-Length"].flatMap({Int($0)})
        }
        
        set(contentLength) {
            headers["Content-Length"] = contentLength?.description
        }
    }
    
    public var transferEncoding: String? {
        get {
            return headers["Transfer-Encoding"]
        }
        
        set(transferEncoding) {
            headers["Transfer-Encoding"] = transferEncoding
        }
    }
    
    public var isChunkEncoded: Bool {
        return transferEncoding == "chunked"
    }
}

extension Response : CustomStringConvertible {
    public var description: String {
        var string: String = ""
        string += String(status.statusCode) + " " + status.reasonPhrase + "\n"
        string += headers.description + "\n"
        string += body.description
        return string
    }
}

extension Response : CustomDebugStringConvertible {
    public var debugDescription: String {
        return description
    }
}
