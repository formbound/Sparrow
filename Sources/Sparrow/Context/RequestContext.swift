import HTTP
import Core
import Foundation

public enum RequestContextError: Error {
    case pathParameterMissing
    case pathParameterConversionFailed(String)
}

public class RequestContext {
    public let request: HTTP.Request
    public let storage: [String: Any] = [:]
    internal(set) public var content: Content
    fileprivate(set) public var log: Logger
    internal(set) public var pathParameters: Parameters

    internal init(request: Request, logger: Logger, pathParameters: Parameters = .empty) {
        self.request = request
        self.content = .null
        self.log = logger
        self.pathParameters = pathParameters
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

public protocol RequestContextResponder {
    func respond(to requestContext: RequestContext) throws -> ResponseContext
}

public struct BasicRequestContextResponder: RequestContextResponder {

    private let handler: (RequestContext) throws -> ResponseContext

    internal init(handler: @escaping (RequestContext) throws -> ResponseContext) {
        self.handler = handler
    }

    public func respond(to requestContext: RequestContext) throws -> ResponseContext {
        return try handler(requestContext)
    }
}
