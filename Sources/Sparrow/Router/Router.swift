import HTTP

public enum RouterError : Error {
    case notFound
    case methodNotAllowed
    
    case parameterNotFound(parameterKey: ParameterKey)
    case invalidParameter(parameter: String, type: ParameterInitializable.Type)
    
    case contentNotFound
    case invalidContent
    
    case unsupportedMediaType
}

extension RouterError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .notFound:
            return Response(status: .notFound, content: "Not found")
        case .methodNotAllowed:
            return Response(status: .methodNotAllowed, content: "Method not allowed")
        case .parameterNotFound:
            return Response(status: .internalServerError, content: "Parameter not found")
        case .invalidParameter:
            return Response(status: .badRequest, content: "Invalid parameter")
        case .contentNotFound:
            return Response(status: .internalServerError, content: "Content not found")
        case .invalidContent:
            return Response(status: .badRequest, content: "Invalid content")
        case .unsupportedMediaType:
            return Response(status: .unsupportedMediaType, content: "Unsupported media type")
        }
    }
}

public final class Router {
    fileprivate var subrouters: [String: Router] = [:]
    fileprivate var pathParameterSubrouter: (String, Router)?
    
    fileprivate var preprocess: (Request) throws -> Void = { _ in }
    fileprivate var responders: [HTTPRequest.Method: (Request) throws -> Response] = [:]
    fileprivate var postprocess: (Response, Request) throws -> Void = { _ in }
    fileprivate var recover: (Error) throws -> Response = { error in throw error }
    
    init() {}
    
    public convenience init(_ body: (Router) -> Void) {
        self.init()
        body(self)
    }
    
    public func add(_ pathComponent: String, body: (Router) -> Void) {
        let route = Router()
        body(route)
        return subrouters[pathComponent] = route
    }
    
    public func add(_ pathParameterKey: ParameterKey, body: (Router) -> Void) {
        let route = Router()
        body(route)
        pathParameterSubrouter = (pathParameterKey.key, route)
    }
    
    public func preprocess(body: @escaping (Request) throws -> Void) {
        preprocess = body
    }
    
    public func respond(method: HTTPRequest.Method, body: @escaping (Request) throws -> Response) {
        responders[method] = body
    }
    
    public func postprocess(body: @escaping (Response, Request) throws -> Void) {
        postprocess = body
    }
    
    public func recover(body: @escaping (Error) throws -> Response) {
        recover = body
    }
}

extension Router {
    public func get(body: @escaping (Request) throws -> Response) {
        respond(method: .get, body: body)
    }
    
    public func post(body: @escaping (Request) throws -> Response) {
        respond(method: .post, body: body)
    }
    
    public func put(body: @escaping (Request) throws -> Response) {
        respond(method: .put, body: body)
    }
    
    public func patch(body: @escaping (Request) throws -> Response) {
        respond(method: .patch, body: body)
    }
    
    public func delete(body: @escaping (Request) throws -> Response) {
        respond(method: .delete, body: body)
    }
}

extension Router : HTTPResponder {
    public func respond(to httpRequest: HTTPRequest) -> HTTPResponse {
        return respond(to: Request(httpRequest: httpRequest)).httpResponse
    }
    
    public func respond(to request: Request) -> Response {
        do {
            return try getResponse(for: request)
        } catch {
            return recover(from: error)
        }
    }
    
    private func getResponse(for request: Request) throws -> Response {
        do {
            try preprocess(request)
            let response = try process(request)
            try postprocess(response, request)
            return response
        } catch {
            return try recover(error)
        }
    }
    
    private func process(_ request: Request) throws -> Response {
        if let pathComponent = request.pathComponents.popFirst() {
            let subrouter = try getSubrouter(for: pathComponent, request: request)
            return try subrouter.getResponse(for: request)
        }
        
        if let respond = responders[request.httpRequest.method] {
            return try respond(request)
        }
        
        throw RouterError.methodNotAllowed
    }
    
    private func getSubrouter(for pathComponent: String, request: Request) throws -> Router {
        if let subrouter = subrouters[pathComponent] {
            return subrouter
        } else if let (pathParameterKey, subrouter) = pathParameterSubrouter {
            request.parameterMapper.set(pathComponent, for: pathParameterKey)
            return subrouter
        }
        
        throw RouterError.notFound
    }
    
    private func recover(from error: Error) -> Response {
        switch error {
        case let error as ResponseRepresentable:
            return error.response
        default:
            return Response(status: .internalServerError, content: "Internal server error")
        }
    }
}
