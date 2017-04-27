import Core

public class Response {
    public var httpResponse: HTTPResponse
    public var content: Content?
    public var headers: HTTPHeaders

    public init(status: HTTPResponse.Status, headers: HTTPHeaders = [:], content: Content? = nil) {
        self.httpResponse = HTTPResponse(status: status, headers: headers)
        self.headers = headers
        self.content = content
    }

    public convenience init(status: HTTPResponse.Status, headers: HTTPHeaders = [:], message: String) {
        self.init(
            status: status,
            headers: headers,
            content: Content(dictionary: ["message": message])
        )
    }

    public convenience init(status: HTTPResponse.Status, headers: HTTPHeaders = [:], content: ContentRepresentable?) {
        self.init(
            status: status,
            headers: headers,
            content: content?.content
        )
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        if let content = content {
            var string: String = ""
            string += String(httpResponse.status.statusCode) + " " + httpResponse.status.reasonPhrase + "\n"
            string += headers.description + "\n"
            string += content.description
            return string
        } else {
            return httpResponse.description
        }
    }
}

extension Response: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard content != nil else {
            return description
        }

        return httpResponse.debugDescription
    }
}
