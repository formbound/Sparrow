import Core
import Venice
import HTTP

public enum ContentNegotiatorError: Error {
    case missingSerializer(MediaType)
    case missingParser(MediaType)
}


public protocol ContentNegotiator: class {

    func parse(body: Body, mediaType: MediaType, deadline: Deadline) throws -> View

    func serialize(view: View, mediaType: MediaType, deadline: Deadline) throws -> Body
}

public class StandardContentNegotiator: ContentNegotiator {

    public func serialize(view: View, mediaType: MediaType, deadline: Deadline) throws -> Body {

        if mediaType == .json {
            return try .data(JSONSerializer.serialize(view))
        }

        throw ContentNegotiatorError.missingSerializer(mediaType)
    }

    public func parse(body: Body, mediaType: MediaType, deadline: Deadline) throws -> View {

        var body = body

        if mediaType == .json {
            return try JSONParser.parse(stream: body.becomeReader(), options: [], deadline: deadline)
        }

        throw ContentNegotiatorError.missingParser(mediaType)
    }
}

