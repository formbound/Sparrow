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
    internal var currentPathParameter: String?

    internal init(request: Request, logger: Logger) {
        self.request = request
        self.content = .null
        self.log = logger
    }
}

extension RequestContext {

    public var hasPathParameter: Bool {
        return currentPathParameter != nil
    }

    public func pathParameter<T: ParameterInitializable>() throws -> T? {

        guard let stringValue = currentPathParameter else {
            return nil
        }

        do {
            return try T(pathParameter: stringValue)
        } catch ParameterConversionError.conversionFailed {
            throw RequestContextError.pathParameterConversionFailed(stringValue)
        } catch {
            throw error
        }
    }

    public func pathParameter<T: ParameterInitializable>() throws -> T {

        guard let value: T = try pathParameter() else {
            throw RequestContextError.pathParameterMissing
        }

        return value
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
