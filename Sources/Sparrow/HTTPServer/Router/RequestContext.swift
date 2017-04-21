import HTTP
import Core

public class RequestContext {
    public let request: HTTP.Request
    public let storage: [String: Any] = [:]
    internal(set) public var pathParameters: Parameters
    internal(set) public var payload: View

    internal init(request: Request, pathParameters: Parameters = .init()) {
        self.request = request
        self.pathParameters = pathParameters
        self.payload = .null
    }
}

extension RequestContext {

    public var queryParameters: Parameters {

        guard let query = request.url.query else {
            return Parameters()
        }

        let components = query.components(separatedBy: "&")

        var result: [String: String] = [:]

        for component in components {
            let pair = component.components(separatedBy: "=")

            guard pair.count == 2 else {
                continue
            }

            result[pair[0]] = pair[1]
        }

        return Parameters(contents: result)
    }

}
