import Core
import Venice
import HTTP

public class ContentNegotiator {

    fileprivate(set) public var accepts: [Support]
    fileprivate(set) public var produces: [Support]

    public enum Support {
        case json

        public static var all: [Support] {
            return [.json]
        }

        var mediaType: MediaType {
            switch self {
            case .json:
                return .json
            }
        }
    }

    public enum Error: Swift.Error {
        case unsupportedMediaTypes([MediaType])
    }

    public convenience init(supportedTypes: [Support] = Support.all) {
        self.init(accepts: supportedTypes, produces: supportedTypes)
    }

    public init(accepts: [Support], produces: [Support]) {
        self.accepts = accepts
        self.produces = produces
    }
}

public extension ContentNegotiator {

    public func serialize(content: Content, mediaType: MediaType, deadline: Deadline) throws -> (HTTPBody, MediaType) {

        guard let supportedMediaType = produces.filter({
            $0.mediaType.matches(other: mediaType)
        }).first else {
            throw Error.unsupportedMediaTypes([mediaType])
        }

        switch supportedMediaType {
        case .json:
            return (try .data(JSONSerializer.serialize(content)), supportedMediaType.mediaType)
        }
    }

    public func parse(body: HTTPBody, mediaType: MediaType, deadline: Deadline) throws -> Content {

        guard let supportedMediaType = accepts.filter({
            $0.mediaType.matches(other: mediaType)
        }).first else {
            throw Error.unsupportedMediaTypes([mediaType])
        }

        var body = body

        switch supportedMediaType {
        case .json:
            return try JSONParser.parse(stream: body.becomeReader(), options: [], deadline: deadline)
        }
    }
}

extension ContentNegotiator {
    public func parse(body: HTTPBody, mediaTypes: [MediaType], deadline: Deadline) throws -> Content {

        var mediaTypes = mediaTypes

        if mediaTypes.isEmpty {
            mediaTypes = Support.all.map { $0.mediaType }
        }

        for mediaType in mediaTypes {
            guard let content = try? parse(body: body, mediaType: mediaType, deadline: deadline) else {
                continue
            }

            return content
        }

        throw Error.unsupportedMediaTypes(mediaTypes)
    }

    public func serialize(content: Content, mediaTypes: [MediaType], deadline: Deadline) throws -> (HTTPBody, MediaType) {

        var mediaTypes = mediaTypes

        if mediaTypes.isEmpty {
            mediaTypes = Support.all.map { $0.mediaType }
        }

        for mediaType in mediaTypes {
            guard let result = try? serialize(content: content, mediaType: mediaType, deadline: deadline) else {
                continue
            }

            return result
        }

        throw Error.unsupportedMediaTypes(mediaTypes)
    }
}
