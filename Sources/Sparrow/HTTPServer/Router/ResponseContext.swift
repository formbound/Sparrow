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
