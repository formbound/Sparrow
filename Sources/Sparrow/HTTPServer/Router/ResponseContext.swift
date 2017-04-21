import Core

public enum ResponseContext {
    case view(Response.Status, Headers, View)
    case response(Response)

    public init(response: Response) {
        self = .response(response)
    }

    public init(status: Response.Status, headers: Headers = [:], view: View) {
        self = .view(status, headers, view)
    }

    public init(status: Response.Status, headers: Headers = [:], message: String) {
        self.init(status: status, headers: headers, view: ["message": message])
    }

    public init(status: Response.Status, headers: Headers = [:], view: ViewRepresentable) {
        self.init(status: status, headers: headers, view: view.view)
    }
}
