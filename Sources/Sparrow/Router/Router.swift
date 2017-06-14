import Zewo

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

final public class Router {
    private typealias Preprocess = (_ request: Request) throws -> Void
    private typealias Postprocess = (_ response: Response, _ request: Request) throws -> Void
    private typealias Recover = (_ error: Error, _ request: Request) throws -> Response
    private typealias Respond = (_ request: Request) throws -> Response
    
    fileprivate var subrouters: [String: Router] = [:]
    fileprivate var pathParameterSubrouter: (String, Router)?
    
    private var preprocess: Preprocess = { _ in }
    private var responders: [Request.Method: Respond] = [:]
    private var postprocess: Postprocess = { _, _ in }
    private var recover: Recover = { error, _ in throw error }
    
    public convenience init(root: RouteNode) {
        self.init(route: root)
    }
    
    private init(route: RouteNode) {
        preprocess = route.preprocess
        responders[.get] = route.get
        responders[.post] = route.post
        responders[.put] = route.put
        responders[.patch] = route.patch
        responders[.delete] = route.delete
        responders[.head] = route.head
        responders[.options] = route.options
        responders[.trace] = route.trace
        responders[.connect] = route.connect
        postprocess = route.postprocess
        recover = route.recover

        for (subpath, route) in route.children {
            subrouters[subpath] = Router(route: route)
        }
        
        if !(route.pathParameterChild is NoPathParameterChild) {
            pathParameterSubrouter = (
                type(of: route.pathParameterChild).pathParameterKey,
                Router(route: route.pathParameterChild)
            )
        }
    }
    
    public func respond(to request: Request) -> Response {
        var chain: [Router] = []
        var visited: [Router] = []
        var pathComponents = PathComponents(request.uri.path ?? "/")
        var pathParameters: [String: String] = [:]

        let response = recover(request, visited: &visited) { visited in
            do {
                let respondingRouter = try match(
                    chain: &chain,
                    pathComponents: &pathComponents,
                    parameters: &pathParameters
                )
                
                guard let responder = respondingRouter.responders[request.method] else {
                    throw RouterError.methodNotAllowed
                }
                
                for (key, parameter) in pathParameters {
                    request.uri.set(parameter: parameter, key: key)
                }
                
                for router in chain {
                    visited.append(router)
                    try router.preprocess(request)
                }
                
                return try responder(request)
            } catch {
                visited.append(self)
                throw error
            }
        }
        
        return recover(request, visited: &visited) { visited in
            while let router = visited.popLast() {
                try router.postprocess(response, request)
            }
            
            return response
        }
    }
    
    private func recover(
        _ request: Request,
        visited: inout [Router],
        _ body: (inout [Router]) throws -> Response
    ) -> Response {
        do {
            return try body(&visited)
        } catch {
            Logger.error("Error while processing request. Trying to recover.", error: error)
            var lastError = error
            var lastRouter = visited.last
            
            while let router = visited.popLast() {
                lastRouter = router
                
                do {
                    let response = try router.recover(lastError, request)
                    Logger.error("Recovered error.", error: lastError)
                    visited.append(router)
                    return response
                } catch let error as (Error & ResponseRepresentable) {
                    Logger.error("Error can be represented as a response. Recovering.", error: error)
                    visited.append(router)
                    return error.response
                } catch {
                    Logger.error("Error while recovering.", error: error)
                    lastError = error
                }
            }
            
            Logger.error("Unrecovered error while processing request.")
            
            if let router = lastRouter {
                visited.append(router)
            }
            
            return Response(status: .internalServerError)
        }
    }
    
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

extension Router : CustomStringConvertible {
    /// :nodoc:
    public var description: String {
        var string = description(path: "")
        string.characters.removeLast()
        return string
    }
    
    private func description(path: String) -> String {
        var string = ""
            
        if path == "" {
            string += "/"
        }
        
        string += path + "\n"
        
        for (pathComponent, subrouter) in subrouters.sorted(by: { $0.0 < $1.0 }) {
            string += subrouter.description(path: path + "/" + pathComponent)
        }
        
        if let (parameterKey, subrouter) = pathParameterSubrouter {
            string += subrouter.description(path: path + "/{" + parameterKey + "}")
        }
        
        return string
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
