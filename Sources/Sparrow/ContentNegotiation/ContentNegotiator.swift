import Core
import Venice
import HTTP

public enum ContentNegotiationError : Error {
    case noSuitableParser
    case noSuitableSerializer
    case noReadableBody
    case noRequestContentType
}

public struct ContentNegotiator {
    public let acceptingMediaTypes: [MediaType]
    public let contentTypes: Set<ContentType>
    public let parseTimeout: Duration
    public let serializeTimeout: Duration

    public var mediaTypes: [MediaType] {
        return contentTypes.map { $0.mediaType }
    }

    public init(
        request: Request,
        contentTypes: Set<ContentType>,
        parseTimeout: Duration? = nil,
        serializeTimeout: Duration? = nil
    ) {
        self.acceptingMediaTypes = request.accept
        self.contentTypes = contentTypes
        self.parseTimeout = parseTimeout ?? 30.seconds
        self.serializeTimeout = serializeTimeout ?? 30.seconds
    }

    public init(
        request: Request,
        parseTimeout: Duration? = nil,
        serializeTimeout: Duration? = nil
    ) {
        self.init(
            request: request,
            contentTypes: [.json],
            parseTimeout: parseTimeout,
            serializeTimeout: serializeTimeout
        )
    }
}

extension ContentNegotiator {

    internal func parse(_ request: Request, deadline: Deadline) throws -> Content {

        guard let contentType = request.contentType else {
            throw ContentNegotiationError.noRequestContentType
        }

        guard let stream = request.body.readable else {
            throw ContentNegotiationError.noReadableBody
        }

        return try parse(
            stream: stream,
            mediaType: contentType
        )
    }

    fileprivate func parse(stream: ReadableStream, mediaType: MediaType) throws -> Content {
        guard let parserType = firstParserType(for: mediaType) else {
            throw ContentNegotiationError.noSuitableParser
        }

        do {
            return try parserType.parse(stream, deadline: parseTimeout.fromNow())
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

    private func firstParserType(for mediaType: MediaType) -> ContentParser.Type? {
        return parserTypes(for: mediaType).first
    }
}


extension ContentNegotiator {

    fileprivate func serialize(content: Content, to response: Response, accepting acceptedMediaTypes: [MediaType]) throws {

        let mediaTypes: [MediaType]

        if let contentType = response.contentType {
            mediaTypes = [contentType]
        } else {
            mediaTypes = acceptedMediaTypes.isEmpty ? self.mediaTypes : acceptedMediaTypes
        }

        let (mediaType, write) = try serializeToStream(
            from: content,
            mediaTypes: mediaTypes
        )

        response.contentType = mediaType
        response.contentLength = nil
        response.transferEncoding = "chunked"
        response.body = .writable(write)
    }

    private func serializeToStream(
        from content: Content,
        mediaTypes: [MediaType]
        ) throws -> (MediaType, Body.Write)  {
        for acceptedType in mediaTypes {
            for (mediaType, serializerType) in serializerTypes(for: acceptedType) {
                return (mediaType, { stream in
                    try serializerType.serialize(
                        content,
                        stream: stream,
                        deadline: self.serializeTimeout.fromNow()
                    )
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
}

