import Core
import Venice
import HTTP

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

public struct ContentNegotiator {
    public let contentTypes: [ContentType]
    private let mediaTypes: [MediaType]
    
    internal init() {
        self.init(contentTypes: .json)
    }

    public init(contentTypes: [ContentType]) {
        self.contentTypes = contentTypes
        self.mediaTypes = contentTypes.map({$0.mediaType})
    }

    public init(contentTypes: ContentType...) {
        self.init(contentTypes: contentTypes)
    }
    
    internal func parse(_ request: Request, deadline: Deadline) throws {
        guard request.content == nil else {
            return
        }
        
        guard let contentType = request.contentType else {
            return
        }
        
        guard let stream = request.body.readable else {
            return
        }
        
        let content = try parse(
            stream: stream,
            deadline: deadline,
            mediaType: contentType
        )

        request.content = content
    }
    
    private func parse(stream: ReadableStream, deadline: Deadline, mediaType: MediaType) throws -> Content {
        let parserType = try firstParserType(for: mediaType)
        
        do {
            return try parserType.parse(stream, deadline: deadline)
        } catch {
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
    
    internal func serialize(_ response: Response, for request: Request, deadline: Deadline) throws {
        guard let content = response.content else {
            return
        }
        
        let mediaTypes: [MediaType]
        
        if let contentType = response.contentType {
            mediaTypes = [contentType]
        } else {
            mediaTypes = request.accept.isEmpty ? self.mediaTypes : request.accept
        }
        
        let (mediaType, write) = try serializeToStream(
            from: content,
            deadline: deadline,
            mediaTypes: mediaTypes
        )
        
        response.contentType = mediaType
        response.contentLength = nil
        response.transferEncoding = "chunked"
        response.body = .writable(write)
    }
    
    private func serializeToStream(
        from content: Content,
        deadline: Deadline,
        mediaTypes: [MediaType]
    ) throws -> (MediaType, Body.Write)  {
        for acceptedType in mediaTypes {
            for (mediaType, serializerType) in serializerTypes(for: acceptedType) {
                return (mediaType, { stream in
                    try serializerType.serialize(content, stream: stream, deadline: deadline)
                })
            }
        }
        
        throw ContentNegotiationError.noSuitableSerializer
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
