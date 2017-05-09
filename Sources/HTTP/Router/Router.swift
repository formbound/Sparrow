import Core

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
    
    public func add(path: String, body: (Router) -> Void) {
        let route = Router()
        body(route)
        return subrouters[path] = route
    }
    
    public func add(parameter: ParameterKey, body: (Router) -> Void) {
        let route = Router()
        body(route)
        pathParameterSubrouter = (parameter.key, route)
    }
    
    public func preprocess(body: @escaping Preprocess) {
        preprocess = body
    }
    
    public func respond(method: Method, body: @escaping Respond) {
        responders[method] = body
    }
    
    public func postprocess(body: @escaping Postprocess) {
        postprocess = body
    }
    
    public func recover(body: @escaping Recover) {
        recover = body
    }
}

extension Router {
    public func get(body: @escaping Respond) {
        respond(method: .get, body: body)
    }
    
    public func post(body: @escaping Respond) {
        respond(method: .post, body: body)
    }
    
    public func put(body: @escaping Respond) {
        respond(method: .put, body: body)
    }
    
    public func patch(body: @escaping Respond) {
        respond(method: .patch, body: body)
    }
    
    public func delete(body: @escaping Respond) {
        respond(method: .delete, body: body)
    }
}

extension Router {
    public func respond(to request: Request) -> Response {
        do {
            var pathComponents = request.url.pathComponents.dropFirst()
            return try respond(to: request, pathComponents: &pathComponents)
        } catch {
            return recover(from: error)
        }
    }
    
    @inline(__always)
    private func respond(to request: Request, pathComponents: inout ArraySlice<String>) throws -> Response {
        do {
            try preprocess(request)
            let response = try process(request, pathComponents: &pathComponents)
            try postprocess(response, request)
            return response
        } catch {
            return try recover(error)
        }
    }
    
    @inline(__always)
    private func process(_ request: Request, pathComponents: inout ArraySlice<String>) throws -> Response {
        if let pathComponent = pathComponents.popFirst() {
            let subrouter = try getSubrouter(for: pathComponent, request: request)
            return try subrouter.respond(to: request, pathComponents: &pathComponents)
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
            request.parameters.set(pathComponent, for: pathParameterKey)
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
