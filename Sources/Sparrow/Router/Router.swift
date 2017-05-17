import HTTP
import Venice

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
    internal typealias Preprocess = (Request) throws -> Void
    internal typealias Postprocess = (Response, Request) throws -> Void
    internal typealias Recover = (Error) throws -> Response
    public typealias Respond = (_ request: Request) throws -> Response
    
    fileprivate var subrouters: [String: Router] = [:]
    fileprivate var pathParameterSubrouter: (String, Router)?
    
    fileprivate var preprocess: Preprocess = { _ in }
    fileprivate var responders: [Method: Respond] = [:]
    fileprivate var postprocess: Postprocess = { _ in }
    fileprivate var recover: Recover = { error in throw error }

    internal func add(subpath: String, body: (Router) -> Void) {
        let route = Router()
        body(route)
        return subrouters[subpath] = route
    }
    
    internal func add(parameter: String, body: (Router) -> Void) {
        let route = Router()
        body(route)
        pathParameterSubrouter = (parameter, route)
    }
    
    internal func preprocess(body: @escaping Preprocess) {
        preprocess = body
    }
    
    internal func respond(method: Method, body: @escaping Respond) {
        responders[method] = body
    }
    
    internal func postprocess(body: @escaping Postprocess) {
        postprocess = body
    }
    
    internal func recover(body: @escaping Recover) {
        recover = body
    }

    public func respond(to request: Request) -> Response {
        do {
            return try process(request: request)
        } catch let error as ResponseRepresentable {
            return error.response
        } catch {
            return Response(status: .internalServerError)
        }
    }

    @inline(__always)
    private func process(request: Request) throws -> Response {
        var chain: [Router] = []
        var pathComponents = PathComponents(request.uri.path ?? "/")
        var pathParameters: [String: String] = [:]
        
        let respondingRouter = try match(
            chain: &chain,
            pathComponents: &pathComponents,
            parameters: &pathParameters
        )

        guard let responder = respondingRouter.responders[request.method] else {
            throw RouterError.methodNotAllowed
        }

        for (key, value) in pathParameters {
            request.uri.parameters.set(value, for: key)
        }

        do {
            for router in chain {
                try router.preprocess(request)
            }

            let response = try responder(request)

            for router in chain.reversed() {
                try router.postprocess(response, request)
            }

            return response
        } catch {
            var lastError = error
            
            while let router = chain.popLast() {
                do {
                    return try router.recover(lastError)
                } catch {
                    lastError = error
                }
            }

            throw error
        }
    }
    
    @inline(__always)
    private func match(
        chain: inout [Router],
        pathComponents: inout PathComponents,
        parameters: inout [String: String]
    ) throws -> Router {
        chain.append(self)
        
        guard let pathComponent = pathComponents.popPathComponent() else {
            return self
        }
        
        if let subrouter = subrouters[pathComponent] {
            return try subrouter.match(
                chain: &chain,
                pathComponents: &pathComponents,
                parameters: &parameters
            )
        }
        
        if let (pathParameterKey, subrouter) = pathParameterSubrouter {
            parameters[pathParameterKey] = pathComponent
            return try subrouter.match(
                chain: &chain,
                pathComponents: &pathComponents,
                parameters: &parameters
            )
        }
        
        throw RouterError.notFound
    }
}

fileprivate struct PathComponents {
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
