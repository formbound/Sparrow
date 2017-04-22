import Core

public enum ResponseContext {
    case content(Response.Status, Headers, Content)
    case response(Response)

    public init(response: Response) {
        self = .response(response)
    }

    public init(status: Response.Status, headers: Headers = [:], content: Content) {
        self = .content(status, headers, content)
    }

    public init(status: Response.Status, headers: Headers = [:], message: String) {
        self.init(status: status, headers: headers, content: ["message": message])
    }

    public init(status: Response.Status, headers: Headers = [:], content: ContentRepresentable) {
        self.init(status: status, headers: headers, content: content.content)
    }
}

extension ResponseContext: CustomStringConvertible {
    public var description: String {
        switch self {
        case .response(let response):
            return response.description
        case .content(let status, let headers, let content):
            var string: String = ""
            string += String(status.statusCode) + " " + status.reasonPhrase + "\n"
            string += headers.description + "\n"
            string += content.description
            return string
        }
    }
}

extension ResponseContext: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .response(let response):
            return response.debugDescription
        case .content:
            return self.description
        }
    }
}
