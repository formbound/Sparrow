import Core
import Venice
import HTTP

// TODO: Make error CustomStringConvertible and ResponseRepresentable
public enum ContentNegotiationError : Error {
    case noSuitableParser
    case noSuitableSerializer
    case noReadableBody
    case noRequestContentType
    case noContent
}

public struct ContentNegotiation {
    public let content: Content?
    public let acceptedType: ContentType
    
    public func getContent() throws -> Content {
        guard let content = content else {
            throw ContentNegotiationError.noContent
        }
        
        return content
    }
    
    public func getContent<C : ContentInitializable>() throws -> C {
        let content = try getContent()
        return try C(content: content)
    }
}

public struct ContentNegotiator {
    public let contentTypes: [ContentType]
    public let parseTimeout: Duration
    
    public var mediaTypes: [MediaType] {
        return contentTypes.map { $0.mediaType }
    }

    public init(
        contentTypes: ContentType...,
        parseTimeout: Duration = 5.minutes
    ) {
        self.contentTypes = contentTypes
        self.parseTimeout = parseTimeout
    }

    public func negotiate(_ request: Request) throws -> ContentNegotiation {
        guard let acceptedType = acceptedType(for: request.accept) else {
            throw ContentNegotiationError.noSuitableSerializer
        }
    
        return ContentNegotiation(
            content: try? parse(request),
            acceptedType: acceptedType
        )
    }
    
    public func parse(_ request: Request) throws -> Content {
        guard let mediaType = request.contentType else {
            throw ContentNegotiationError.noRequestContentType
        }
        
        guard let stream = request.body.readable else {
            throw ContentNegotiationError.noReadableBody
        }
        
        guard let contentType = contentType(for: mediaType) else {
            throw ContentNegotiationError.noSuitableParser
        }
        
        return try contentType.parser.parse(stream, deadline: parseTimeout.fromNow())
    }
    
    public func parse<C : ContentInitializable>(_ request: Request) throws -> C {
        let content = try parse(request)
        return try C(content: content)
    }

    private func contentType(for mediaType: MediaType) -> ContentType? {
        for contentType in contentTypes where contentType.mediaType.matches(other: mediaType) {
            return contentType
        }
        
        return nil
    }
    
    private func acceptedType(for acceptableTypes: [MediaType]) -> ContentType? {
        if acceptableTypes.isEmpty {
            return contentTypes.first
        }
        
        for acceptableType in acceptableTypes {
            for contentType in contentTypes {
                if contentType.mediaType.matches(other: acceptableType) {
                    return contentType
                }
            }
        }
        
        return nil
    }
}
