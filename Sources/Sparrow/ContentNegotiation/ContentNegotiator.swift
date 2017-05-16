import Core
import Venice
import HTTP

public enum ContentNegotiationError : Error {
    case noSuitableParser
    case noSuitableSerializer
    case noReadableBody
    case noRequestContentType
}

public struct ContentNegotiation {
    public let content: Content
    public let acceptedType: ContentType
    
    public func getContent<C : ContentInitializable>() throws -> C {
        return try C(content: content)
    }
}

public struct ContentNegotiator {
    public let contentTypes: [ContentType]
    
    public var mediaTypes: [MediaType] {
        return contentTypes.map { $0.mediaType }
    }

    public init(
        contentTypes: ContentType...
    ) {
        self.contentTypes = contentTypes
    }

    public func negotiate(_ request: Request, deadline: Deadline) throws -> ContentNegotiation {
        guard let mediaType = request.contentType else {
            throw ContentNegotiationError.noRequestContentType
        }

        guard let stream = request.body.readable else {
            throw ContentNegotiationError.noReadableBody
        }
        
        guard let acceptedType = acceptedType(for: request.accept) else {
            throw ContentNegotiationError.noSuitableSerializer
        }
    
        return ContentNegotiation(
            content: try parse(stream: stream, mediaType: mediaType, deadline: deadline),
            acceptedType: acceptedType
        )
    }
    
    public func parse(_ request: Request, deadline: Deadline) throws -> Content {
        guard let mediaType = request.contentType else {
            throw ContentNegotiationError.noRequestContentType
        }
        
        guard let stream = request.body.readable else {
            throw ContentNegotiationError.noReadableBody
        }
       
        return try parse(stream: stream, mediaType: mediaType, deadline: deadline)
    }
    
    public func parse<C : ContentInitializable>(_ request: Request, deadline: Deadline) throws -> C {
        let content = try parse(request, deadline: deadline)
        return try C(content: content)
    }

    private func parse(
        stream: ReadableStream,
        mediaType: MediaType,
        deadline: Deadline
    ) throws -> Content {
        guard let contentType = contentType(for: mediaType) else {
            throw ContentNegotiationError.noSuitableParser
        }

        return try contentType.parser.parse(stream, deadline: deadline)
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
