import Core
import Venice
import HTTP

public enum ContentNegotiatorError: Error {
    case unsupportedMediaTypes([MediaType])
}

public protocol ContentNegotiator: class {

    func parse(body: Body, mediaType: MediaType, deadline: Deadline) throws -> View

    func serialize(view: View, mediaType: MediaType, deadline: Deadline) throws -> (Body, MediaType)

    func view(for error: HTTPError) -> View
}

public extension ContentNegotiator {
    public func parse(body: Body, mediaTypes: [MediaType], deadline: Deadline) throws -> View {
        for mediaType in mediaTypes {
            guard let view = try? parse(body: body, mediaType: mediaType, deadline: deadline) else {
                continue
            }

            return view
        }

        throw ContentNegotiatorError.unsupportedMediaTypes(mediaTypes)
    }

    public func serialize(view: View, mediaTypes: [MediaType], deadline: Deadline) throws -> (Body, MediaType) {
        for mediaType in mediaTypes {
            guard let result = try? serialize(view: view, mediaType: mediaType, deadline: deadline) else {
                continue
            }

            return result
        }

        throw ContentNegotiatorError.unsupportedMediaTypes(mediaTypes)
    }

    public func serialize(error: HTTPError, mediaTypes: [MediaType], deadline: Deadline) throws -> (Body, MediaType) {
        return try serialize(view: view(for: error), mediaTypes: mediaTypes, deadline: deadline)
    }
}

public class StandardContentNegotiator: ContentNegotiator {

    public func view(for error: HTTPError) -> View {
        return [
            "error": error.reason
        ]
    }

    public func serialize(view: View, mediaType: MediaType, deadline: Deadline) throws -> (Body, MediaType) {

        switch mediaType {
        case MediaType.json:
            return (try .data(JSONSerializer.serialize(view)), mediaType)
        default:
            throw ContentNegotiatorError.unsupportedMediaTypes([mediaType])
        }
    }

    public func parse(body: Body, mediaType: MediaType, deadline: Deadline) throws -> View {

        var body = body

        switch mediaType {
        case MediaType.json:
            return try JSONParser.parse(stream: body.becomeReader(), options: [], deadline: deadline)
        default:
            throw ContentNegotiatorError.unsupportedMediaTypes([mediaType])
        }
    }
}
