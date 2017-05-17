import Core
import Venice
import HTTP

// TODO: Make error CustomStringConvertible and ResponseRepresentable
public enum ContentNegotiationError : Error {
    case noSuitableSerializer
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
    
    public var mediaTypes: [MediaType] {
        return contentTypes.map { $0.mediaType }
    }

    public init(contentTypes: ContentType...) {
        self.contentTypes = contentTypes
    }

    public func negotiate(_ request: Request, deadline: Deadline = 5.minutes.fromNow()) throws -> ContentNegotiation {
        guard let acceptedType = acceptedType(for: request.accept) else {
            throw ContentNegotiationError.noSuitableSerializer
        }
    
        return ContentNegotiation(
            content: parse(request, deadline: deadline),
            acceptedType: acceptedType
        )
    }
    
    private func parse(_ request: Request, deadline: Deadline) -> Content? {
        guard let mediaType = request.contentType else {
            return nil
        }
        
        guard let contentType = contentType(for: mediaType) else {
            return nil
        }
        
        return try? request.getContent(contentType, deadline: deadline)
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
