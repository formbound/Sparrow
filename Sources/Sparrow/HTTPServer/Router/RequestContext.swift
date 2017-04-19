import HTTP

public class RequestContext {
    public let request: HTTP.Request
    public let storage: [String: Any] = [:]
    public let pathParameters: PathParameters

    init(request: Request, pathParameters: PathParameters) {
        self.request = request
        self.pathParameters = pathParameters
    }
}
