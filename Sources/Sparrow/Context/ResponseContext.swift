import Core

public class ResponseContext {
    public var response: Response
    public var content: Content?
    public var headers: Headers

    public init(status: Response.Status, headers: Headers = [:], content: Content? = nil) {
        self.response = Response(status: status, headers: headers)
        self.headers = headers
        self.content = content
    }

    public convenience init(status: Response.Status, headers: Headers = [:], message: String) {
        self.init(
            status: status,
            headers: headers,
            content: ["message": message]
        )
    }

    public convenience init(status: Response.Status, headers: Headers = [:], content: ContentRepresentable) {
        self.init(
            status: status,
            headers: headers,
            content: content.content
        )
    }
}

extension ResponseContext: CustomStringConvertible {
    public var description: String {
        if let content = content {
            var string: String = ""
            string += String(response.status.statusCode) + " " + response.status.reasonPhrase + "\n"
            string += headers.description + "\n"
            string += content.description
            return string
        } else {
            return response.description
        }
    }
}

extension ResponseContext: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard content != nil else {
            return description
        }

        return response.debugDescription
    }
}
