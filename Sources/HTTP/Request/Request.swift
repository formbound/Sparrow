import Core
import struct Foundation.URL

public final class Request : Message {
    public let method: Method
    public let url: URL
    public let version: Version
    public let headers: Headers
    public let body: InputStream
    
    public var content: Content?
    public var storage: Storage = [:]
        
    var pathComponents: ArraySlice<String>
    
//    var parameterMapper: ParameterMapper
//    var contentMapper = ContentMapper()
    
    public init(
        method: Method,
        url: URL,
        version: Version = .oneDotOne,
        headers: Headers = [:],
        body: InputStream = DataStream()
    ) {
        self.method = method
        self.url = url
        self.version = version
        self.headers = headers
        self.body = body
        
        self.pathComponents = url.pathComponents.dropFirst()
//        self.parameterMapper = ParameterMapper(url: url)
    }
}

extension Request {
    public convenience init?(
        method: Method,
        url: String,
        version: Version = .oneDotOne,
        headers: Headers = [:],
        body: InputStream = DataStream()
    ) {
        guard let url = URL(string: url) else {
            return nil
        }
        
        self.init(
            method: method,
            url: url,
            version: version,
            headers: headers,
            body: body
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


//extension Request {
//    public func getParameters<P : ParameterMappable>() throws -> P {
//        return try P(mapper: parameterMapper)
//    }
//    
//    public func getContent<C : ContentMappable>() throws -> C {
//        return try C(mapper: contentMapper)
//    }
//}
