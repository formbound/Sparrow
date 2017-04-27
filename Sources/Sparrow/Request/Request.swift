import HTTP
import Core
import Foundation

public class Request {
    public let httpRequest: HTTPRequest
    public let storage: [String: Any] = [:]
    internal(set) public var content: Content
    fileprivate(set) public var log: Logger
    internal(set) public var pathParameters: Parameters

    internal init(request: HTTPRequest, logger: Logger, pathParameters: Parameters = .empty) {
        self.httpRequest = request
        self.content = .null
        self.log = logger
        self.pathParameters = pathParameters
    }
}

extension Request {

    public var queryParameters: Parameters {

        guard let query = httpRequest.url.query else {
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

public protocol RequestResponder {
    func respond(to request: Request) throws -> Response
}

public struct BasicRequestResponder: RequestResponder {

    private let handler: (Request) throws -> Response

    internal init(handler: @escaping (Request) throws -> Response) {
        self.handler = handler
    }

    public func respond(to request: Request) throws -> Response {
        return try handler(request)
    }
}
