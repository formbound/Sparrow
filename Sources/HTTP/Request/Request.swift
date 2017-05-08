import Core
import Foundation

public final class Request : Message {
    public typealias UpgradeConnection = (Response, DuplexStream) throws -> Void
    
    public var method: Method
    public var url: URL
    public var version: Version
    public var headers: Headers
    public var body: Body
    
    public var content: Content?
    public var storage: Storage = [:]
    
    public var upgradeConnection: UpgradeConnection?
    
    lazy var parameters: Parameters = Parameters(url: self.url)
    
    public init(
        method: Method,
        url: URL,
        headers: Headers = [:],
        version: Version = .oneDotOne,
        body: Body
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.version = version
        self.body = body
    }
}

extension Request {
    public convenience init(
        method: Method,
        url: URL,
        headers: Headers = [:]
    ) {
        self.init(
            method: method,
            url: url,
            headers: headers,
            version: .oneDotOne,
            body: .empty
        )
        
        self.headers.contentLength = 0
    }
    
    public convenience init(
        method: Method,
        url: URL,
        headers: Headers = [:],
        body stream: ReadableStream
    ) {
        self.init(
            method: method,
            url: url,
            headers: headers,
            version: .oneDotOne,
            body: .readable(stream)
        )
    }
}

extension Request {
    public var accept: [MediaType] {
        get {
            var acceptedMediaTypes: [MediaType] = []
            
            if let acceptString = headers["Accept"] {
                let acceptedTypesString = acceptString.components(separatedBy: ",")
                
                for acceptedTypeString in acceptedTypesString {
                    let acceptedTypeTokens = acceptedTypeString.components(separatedBy: ";")
                    
                    if acceptedTypeTokens.count >= 1 {
                        let mediaTypeString = acceptedTypeTokens[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let acceptedMediaType = try? MediaType(string: mediaTypeString) {
                            acceptedMediaTypes.append(acceptedMediaType)
                        }
                    }
                }
            }
            
            return acceptedMediaTypes
        }
    }
    
    public var cookies: Set<Cookie> {
        get {
            return headers["Cookie"].flatMap({Set<Cookie>(cookieHeader: $0)}) ?? []
        }
    }
    
    public var authorization: String? {
        get {
            return headers["Authorization"]
        }
    }
    
    public var host: String? {
        get {
            return headers["Host"]
        }
    }
    
    public var userAgent: String? {
        get {
            return headers["User-Agent"]
        }
    }
}

extension Request : CustomStringConvertible {
    public var requestLineDescription: String {
        return method.description + " " + url.absoluteString + " HTTP/" + version.description + "\n"
    }
    
    public var description: String {
        return requestLineDescription + headers.description
    }
}

extension Request {
    public func getParameters<P : ParametersInitializable>() throws -> P {
        if P.self is NoParameters.Type {
            return NoParameters() as! P
        }
        
        return try P(parameters: parameters)
    }
    
    public func getContent<C : ContentInitializable>() throws -> C {
        if C.self is NoContent.Type {
            return NoContent() as! C
        }
        
        guard let content = content else {
            throw ContentError.cannotInitialize(type: C.self, from: .null)
        }
        
        return try C(content: content)
    }
}
