import HTTP

public enum RouterError : Error {
    case notFound
    case methodNotAllowed
}

extension RouterError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .notFound:
            return Response(status: .notFound)
        case .methodNotAllowed:
            return Response(status: .methodNotAllowed)
        }
    }
}

public final class Router {
    public typealias Preprocess = (Request) throws -> Void
    public typealias Postprocess = (Response, Request) throws -> Void
    public typealias Recover = (Error) throws -> Response
    public typealias Respond = (Request) throws -> Response
    
    fileprivate var subrouters: [String: Router] = [:]
    fileprivate var pathParameterSubrouter: (String, Router)?
    
    fileprivate var preprocess: Preprocess = { _ in }
    fileprivate var responders: [Method: Respond] = [:]
    fileprivate var postprocess: Postprocess = { _ in }
    fileprivate var recover: Recover = { error in throw error }
    
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
    
    public func respond(method: Method, body: @escaping (Request) throws -> Response) {
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

extension Router {
    public func respond(to incoming: IncomingRequest) -> OutgoingResponse {
        return respond(to: Request(incoming)).outgoing
    }
    
    public func respond(to request: Request) -> Response {
        do {
            return try getResponse(for: request)
        } catch {
            return recover(from: error)
        }
    }
    
    @inline(__always)
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
    
    @inline(__always)
    private func process(_ request: Request) throws -> Response {
        if let pathComponent = request.pathComponents.popFirst() {
            let subrouter = try getSubrouter(for: pathComponent, request: request)
            return try subrouter.getResponse(for: request)
        }
        
        if let respond = responders[request.method] {
            return try respond(request)
        }
        
        throw RouterError.methodNotAllowed
    }
    
    @inline(__always)
    private func getSubrouter(for pathComponent: String, request: Request) throws -> Router {
        if let subrouter = subrouters[pathComponent] {
            return subrouter
        } else if let (pathParameterKey, subrouter) = pathParameterSubrouter {
            request.parameterMapper.set(pathComponent, for: pathParameterKey)
            return subrouter
        }
        
        throw RouterError.notFound
    }
    
    @inline(__always)
    private func recover(from error: Error) -> Response {
        switch error {
        case let error as ResponseRepresentable:
            return error.response
        default:
            return Response(status: .internalServerError)
        }
    }
}
