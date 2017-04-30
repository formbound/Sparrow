import Core
import Venice
import HTTP
import Router

public enum ContentNegotiationError : Error {
    case noSuitableParser
    case noSuitableSerializer
}

extension ContentNegotiationError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .noSuitableParser:
            return Response(status: .unsupportedMediaType)
        case .noSuitableSerializer:
            return Response(status: .unsupportedMediaType)
        }
    }
}

public struct ContentType {
    public let mediaType: MediaType
    public let parser: ContentParser.Type
    public let serializer: ContentSerializer.Type
    
    public init(mediaType: MediaType, parser: ContentParser.Type, serializer: ContentSerializer.Type) {
        self.mediaType = mediaType
        self.parser = parser
        self.serializer = serializer
    }
}

extension ContentType {
    public static let json = ContentType(
        mediaType: .json,
        parser: JSONParser.self,
        serializer: JSONSerializer.self
    )
}

public struct ContentNegotiator {
    public let contentTypes: [ContentType]
    private let mediaTypes: [MediaType]
    
    public init() {
        self.init(contentTypes: .json)
    }
    
    public init(contentTypes: ContentType...) {
        self.contentTypes = contentTypes
        self.mediaTypes = contentTypes.map({$0.mediaType})
    }
    
    public func parse(_ request: Request, deadline: Deadline) throws {
        guard let contentType = request.headers.contentType else {
            return
        }
        
        let content = try parse(
            stream: request.incoming.body,
            deadline: deadline,
            mediaType: contentType
        )

        request.content = content
    }
    
    private func parse(stream: InputStream, deadline: Deadline, mediaType: MediaType) throws -> Content {
        let parserType = try firstParserType(for: mediaType)
        
        do {
            return try parserType.parse(stream, deadline: deadline)
        } catch {
            throw ContentNegotiationError.noSuitableParser
        }
    }
    
    private func parse(buffer: [Byte], mediaType: MediaType) throws -> Content {
        var lastError: Error?
        
        for parserType in parserTypes(for: mediaType) {
            do {
                return try parserType.parse(buffer)
            } catch {
                lastError = error
                continue
            }
        }
        
        if let lastError = lastError {
            throw lastError
        } else {
            throw ContentNegotiationError.noSuitableParser
        }
    }
    
    private func parserTypes(for mediaType: MediaType) -> [ContentParser.Type] {
        var parsers: [ContentParser.Type] = []
        
        for contentType in contentTypes where contentType.mediaType.matches(other: mediaType) {
            parsers.append(contentType.parser)
        }
        
        return parsers
    }
    
    private func firstParserType(for mediaType: MediaType) throws -> ContentParser.Type {
        guard let first = parserTypes(for: mediaType).first else {
            throw ContentNegotiationError.noSuitableParser
        }
        
        return first
    }
    
    public func serialize(_ response: Response, for request: Request, deadline: Deadline) throws {
        guard let content = response.content else {
            return
        }
        
        let mediaTypes: [MediaType]
        
        if let contentType = response.headers.contentType {
            mediaTypes = [contentType]
        } else {
            mediaTypes = request.headers.accept.isEmpty ? self.mediaTypes : request.headers.accept
        }
        
        let (mediaType, writer) = try serializeToStream(
            from: content,
            deadline: deadline,
            mediaTypes: mediaTypes
        )
        
        response.headers.contentType = mediaType
        response.headers.contentLength = nil
        response.headers.transferEncoding = "chunked"
        response.body = writer
    }
    
    private func serializeToStream(
        from content: Content,
        deadline: Deadline,
        mediaTypes: [MediaType]
    ) throws -> (MediaType, (OutputStream) throws -> Void)  {
        for acceptedType in mediaTypes {
            for (mediaType, serializerType) in serializerTypes(for: acceptedType) {
                return (mediaType, { stream in
                    try serializerType.serialize(content, stream: stream, deadline: deadline)
                })
            }
        }
        
        throw ContentNegotiationError.noSuitableSerializer
    }
    
    private func serializeToBuffer(
        from content: Content,
        mediaTypes: [MediaType]
    ) throws -> (MediaType, [Byte]) {
        var lastError: Error?
        
        for acceptedType in mediaTypes {
            for (mediaType, serializerType) in serializerTypes(for: acceptedType) {
                do {
                    let buffer = try serializerType.serialize(content)
                    return (mediaType, buffer)
                } catch {
                    lastError = error
                    continue
                }
            }
        }
        
        if let lastError = lastError {
            throw lastError
        } else {
            throw ContentNegotiationError.noSuitableSerializer
        }
    }
    
    private func serializerTypes(for mediaType: MediaType) -> [(MediaType, ContentSerializer.Type)] {
        var serializers: [(MediaType, ContentSerializer.Type)] = []
        
        for contentType in contentTypes where contentType.mediaType.matches(other: mediaType) {
            serializers.append(contentType.mediaType, contentType.serializer)
        }
        
        return serializers
    }
    
    private func firstSerializerType(
        for mediaType: MediaType
    ) throws -> (MediaType, ContentSerializer.Type) {
        guard let first = serializerTypes(for: mediaType).first else {
            throw ContentNegotiationError.noSuitableSerializer
        }
        
        return first
    }
}
