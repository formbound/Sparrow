import HTTP
import Venice

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
    
    public convenience init(body: (Router) -> Void) {
        self.init()
        body(self)
    }
    
    public func add(path: String, body: (Router) -> Void) {
        let route = Router()
        body(route)
        return subrouters[path] = route
    }
    
    public func add(parameter: String, body: (Router) -> Void) {
        let route = Router()
        body(route)
        pathParameterSubrouter = (parameter, route)
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

    @inline(__always)
    private func matchingRouterChain(
        for pathComponents: [String],
        parameters: inout [String: String]
        ) -> [Router] {

        if pathComponents.isEmpty {
            return [self]
        }

        var pathComponents = pathComponents

        let pathComponent = pathComponents.removeFirst()

        if let subrouter = subrouters[pathComponent] {
            return [self] + subrouter.matchingRouterChain(for: pathComponents, parameters: &parameters)
        }
        else if let (pathParameterKey, subrouter) = pathParameterSubrouter {
            parameters[pathParameterKey] = pathComponent
            return [self] + subrouter.matchingRouterChain(for: pathComponents, parameters: &parameters)
        } else {
            return []
        }
    }

    public func respond(to request: Request) -> Response {
        do {
            return try process(request: request)
        }
        catch let error as RouterError {
            return error.response
        }
        catch {
            return Response(status: .internalServerError)
        }
    }

    @inline(__always)
    private func process(request: Request) throws -> Response {

        var pathComponents: [String]

        // Extract path components from the path trimmed from forward slashes
        if let path = request.uri.path?.trimmingCharacters(in: .init(charactersIn: "/")) {
            pathComponents = path.components(separatedBy: "/")
        }
        else {
            pathComponents = []
        }

        // Path parameters will be extracted from the route chain
        var pathParameters: [String: String] = [:]

        // Find a matching route chain
        let routerChain = matchingRouterChain(for: pathComponents, parameters: &pathParameters)

        // If no route chain is found it's a 404 Not Found
        if routerChain.isEmpty {
            throw RouterError.notFound
        }

        let respondingRouter = routerChain[routerChain.endIndex - 1]

        // Make sure there's a responder for the requested method, or it's a 405 Method Not Allowed
        guard let responder = respondingRouter.responders[request.method] else {
            throw RouterError.methodNotAllowed
        }

        // At this point, the request is ready to be handled by the responder

        for (key, value) in pathParameters {
            request.uri.parameters.set(value, for: key)
        }

        do {
            // Preprocess the request for each router in the chain
            for router in routerChain {
                try router.preprocess(request)
            }

            // Invoke the responder, returning the response
            let response = try responder(request)


            // Postprocess (in reverse order) for each router in the chain
            for router in routerChain.reversed() {
                try router.postprocess(response, request)
            }

            return response
        }
        catch {

            // Try to recover for each router in the chain, reversed
            for router in routerChain.reversed() {
                return try router.recover(error)
            }

            throw error
        }
    }
}
