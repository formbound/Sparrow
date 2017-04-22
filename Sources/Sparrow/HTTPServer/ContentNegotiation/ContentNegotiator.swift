import Core
import Venice
import HTTP



public class ContentNegotiator {

    fileprivate(set) public var accepts: Set<Support>
    fileprivate(set) public var produces: Set<Support>

    public lazy var errorTransformer: (HTTPError) -> ContentRepresentable = { error in
        return Content(
            dictionary: ["error": error.reason ?? "An unexpected error occurred"]
        )
    }

    public enum Support {
        case json

        public static var all: Set<Support> {
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

    public convenience init(supportedTypes: Set<Support> = Support.all) {
        self.init(accepts: supportedTypes, produces: supportedTypes)
    }

    public init(accepts: Set<Support>, produces: Set<Support>) {
        self.accepts = accepts
        self.produces = produces
    }
}

extension ContentNegotiator.Support {
    init?(mediaType: MediaType) {
        switch mediaType {
        case MediaType.json:
            self = .json
        default:
            return nil
        }
    }
}

public extension ContentNegotiator {
    public func content(for error: HTTPError) -> Content {
        return [
            "error": error.reason
        ]
    }

    public func serialize(content: Content, mediaType: MediaType, deadline: Deadline) throws -> (Body, MediaType) {

        guard let supportedMediaType = Support(mediaType: mediaType), produces.contains(supportedMediaType) else {
            throw Error.unsupportedMediaTypes([mediaType])
        }

        switch supportedMediaType {
        case .json:
            return (try .data(JSONSerializer.serialize(content)), supportedMediaType.mediaType)
        }
    }

    public func parse(body: Body, mediaType: MediaType, deadline: Deadline) throws -> Content {

        guard let supportedMediaType = Support(mediaType: mediaType), accepts.contains(supportedMediaType) else {
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
    public func parse(body: Body, mediaTypes: [MediaType], deadline: Deadline) throws -> Content {

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

    public func serialize(content: Content, mediaTypes: [MediaType], deadline: Deadline) throws -> (Body, MediaType) {

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
    
    public func serialize(error: HTTPError, mediaTypes: [MediaType], deadline: Deadline) throws -> (Body, MediaType) {

        var mediaTypes = mediaTypes

        if mediaTypes.isEmpty {
            mediaTypes = Support.all.map { $0.mediaType }
        }

        return try serialize(content: content(for: error), mediaTypes: mediaTypes, deadline: deadline)
    }
}
