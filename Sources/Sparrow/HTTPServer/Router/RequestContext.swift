import HTTP

public class RequestContext {
    public let request: HTTP.Request
    public let storage: [String: Any] = [:]
    internal(set) public var pathParameters: PathParameters

    internal init(request: Request, pathParameters: PathParameters = .init()) {
        self.request = request
        self.pathParameters = pathParameters
    }
}
