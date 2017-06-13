import Core
@_exported import HTTP
import Venice

public enum RouterError : Error {
    case notFound
    case methodNotAllowed
    case parameterRedeclaration
}

extension RouterError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .notFound:
            return Response(status: .notFound)
        case .methodNotAllowed:
            return Response(status: .methodNotAllowed)
        case .parameterRedeclaration:
            return Response(status: .internalServerError)
        }
    }
}

final public class Router {
    public typealias Preprocess = (Request) throws -> Void
    public typealias Postprocess = (Response, Request) throws -> Void
    public typealias Recover = (Error, Request) throws -> Response
    public typealias Respond = (_ request: Request) throws -> Response
    
    internal var subrouters: [String: Router] = [:]
    internal var pathParameterSubrouter: (String, Router)?
    
    internal var preprocess: Preprocess = { _ in }
    internal var responders: [Request.Method: Respond] = [:]
    internal var postprocess: Postprocess = { _, _ in }
    internal var recover: Recover = { error, _ in throw error }

    public init() {}
    
    convenience public init(route: Route) {
        self.init()

        preprocess(body: route.preprocess)
        respond(to: .get, body: route.get)
        respond(to: .post, body: route.post)
        respond(to: .put, body: route.put)
        respond(to: .patch, body: route.patch)
        respond(to: .delete, body: route.delete)
        respond(to: .head, body: route.head)
        respond(to: .options, body: route.options)
        respond(to: .trace, body: route.trace)
        respond(to: .connect, body: route.connect)
        postprocess(body: route.postprocess)

        for (pathComponent, route) in route.children {
            add(pathComponent, route: route)
        }
    }

    public func add(_ pathComponent: PathComponent, route: Route) {
        add(pathComponent, router: Router(route: route))
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

extension Router : CustomStringConvertible {
    /// :nodoc:
    public var description: String {
        var string = description(path: "")
        string.characters.removeLast()
        return string
    }
    
    @inline(__always)
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

public enum PathComponent {
    case subpath(String)
    case parameter(String)
}

extension PathComponent: Hashable {
    public var hashValue: Int {
        switch self {
        case .subpath(let string):
            return string.hashValue
        case .parameter(let string):
            return "%\(string)".hashValue
        }
    }
}

extension PathComponent: Equatable {
    public static func == (lhs: PathComponent, rhs: PathComponent) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension PathComponent : ExpressibleByStringLiteral {
    /// :nodoc:
    public init(unicodeScalarLiteral value: String) {
        self = .subpath(value)
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .subpath(value)
    }
    
    /// :nodoc:
    public init(stringLiteral value: StringLiteralType) {
        self = .subpath(value)
    }
}

prefix operator %

extension String {
    public static prefix func % (parameter: String) -> PathComponent {
        return .parameter(parameter)
    }
}

extension Router {    
    internal func add(_ path: PathComponent, router: Router) {
        switch path {
        case let .subpath(subpath):
            return subrouters[subpath] = router
        case let .parameter(parameter):
            return pathParameterSubrouter = (parameter, router)
        }
    }
}


extension Router {
    public func preprocess(body: @escaping Preprocess) {
        preprocess = body
    }
}

extension Router {
    public func postprocess(body: @escaping Postprocess) {
        postprocess = body
    }
}

extension Router {
    public func recover(body: @escaping Recover) {
        recover = body
    }
}

extension Router {
    public func get(body: @escaping Respond) {
        respond(to: .get, body: body)
    }
    
    public func post(body: @escaping Respond) {
        respond(to: .post, body: body)
    }
    
    public func put(body: @escaping Respond) {
        respond(to: .put, body: body)
    }
    
    public func patch(body: @escaping Respond) {
        respond(to: .patch, body: body)
    }
    
    public func delete(body: @escaping Respond) {
        respond(to: .delete, body: body)
    }
    
    public func head(body: @escaping Respond) {
        respond(to: .head, body: body)
    }
    
    public func options(body: @escaping Respond) {
        respond(to: .options, body: body)
    }
    
    public func trace(body: @escaping Respond) {
        respond(to: .trace, body: body)
    }
    
    public func connect(body: @escaping Respond) {
        respond(to: .connect, body: body)
    }
    
    public func respond(
        to method: Request.Method,
        body: @escaping Respond
    ) {
        responders[method] = body
    }
}

extension Array where Element == PathComponent {
    var string: String {
        var string = ""
        
        if self.isEmpty {
            string += "/"
        }
        
        for component in self {
            string += "/"
            
            switch component {
            case let .subpath(subpath):
                string += subpath
            case let .parameter(parameter):
                string += parameter
            }
        }
        
        return string
    }
}
