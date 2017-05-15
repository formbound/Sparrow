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

    public let contentNegotiator: ContentNegotiator

    public let timeout: Duration
    
    init(contentNegotiator: ContentNegotiator, timeout: Duration) {
        self.contentNegotiator = contentNegotiator
        self.timeout = timeout
    }
    
    public convenience init(contentNegotiator: ContentNegotiator = .init(), timeout: Duration = 10.seconds, body: (Router) -> Void) {
        self.init(contentNegotiator: contentNegotiator, timeout: timeout)
        body(self)
    }
    
    public func add(path: String, body: (Router) -> Void) {
        let route = Router(contentNegotiator: contentNegotiator, timeout: timeout)
        body(route)
        return subrouters[path] = route
    }
    
    public func add(parameter: String, body: (Router) -> Void) {
        let route = Router(contentNegotiator: contentNegotiator, timeout: timeout)
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
    private struct Path {
        private var path: String.CharacterView
        
        fileprivate init(_ path: String) {
            self.path = path.characters.dropFirst()
        }
        
        fileprivate mutating func popPathComponent() -> String? {
            if path.isEmpty {
                return nil
            }
            
            var pathComponent = String.CharacterView()
            
            while let character = path.popFirst() {
                guard character != "/" else {
                    break
                }
                
                pathComponent.append(character)
            }
            
            return String(pathComponent)
        }
    }
    
    public func respond(to request: Request) -> Response {
        do {
            var path = Path(request.uri.path ?? "/")
            return try respond(to: request, path: &path)
        } catch {
            return recover(from: error)
        }
    }
    
    @inline(__always)
    private func respond(to request: Request, path: inout Path) throws -> Response {
        do {
            try preprocess(request)
            let response = try process(request, path: &path)
            try postprocess(response, request)

            try contentNegotiator.serialize(response, for: request, deadline: timeout.fromNow())

            return response
        } catch {
            return try recover(error)
        }
    }
    
    @inline(__always)
    private func process(_ request: Request, path: inout Path) throws -> Response {
        if let pathComponent = path.popPathComponent() {
            let subrouter = try getSubrouter(for: pathComponent, request: request)
            return try subrouter.respond(to: request, path: &path)
        }
        
        if let respond = responders[request.method] {

            if let contentLength = request.contentLength, contentLength > 0 {
                try contentNegotiator.parse(request, deadline: timeout.fromNow())
            }

            return try respond(request)
        }

        throw RouterError.methodNotAllowed
    }
    
    @inline(__always)
    private func getSubrouter(for pathComponent: String, request: Request) throws -> Router {
        if let subrouter = subrouters[pathComponent] {
            return subrouter
        } else if let (pathParameterKey, subrouter) = pathParameterSubrouter {
            request.uri.parameters.set(pathComponent, for: pathParameterKey)
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
