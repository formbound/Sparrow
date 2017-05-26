import Core
import HTTP
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

open class Router {
    public typealias Preprocess = (Request) throws -> Void
    public typealias Postprocess = (Response, Request) throws -> Void
    public typealias Recover = (Error, Request) throws -> Response
    public typealias Respond = (_ request: Request) throws -> Response
    
    internal var subrouters: [String: Router] = [:]
    internal var pathParameterSubrouter: (String, Router)?
    
    internal var preprocess: Preprocess = { _ in }
    internal var responders: [Request.Method: Respond] = [:]
    internal var postprocess: Postprocess = { _ in }
    internal var recover: Recover = { error, _ in throw error }
    
    public init() {
        configure(router: self)
    }
    
    open func configure(router: Router) {}
    
    internal func copy(_ router: Router) {
        // TODO: issue warnings on overwites
        subrouters = router.subrouters
        pathParameterSubrouter = router.pathParameterSubrouter
        preprocess = router.preprocess
        responders = router.responders
        postprocess = router.postprocess
        recover = router.recover
    }
    
    public func respond(to request: Request) -> Response {
        var chain: [Router] = []
        var visited: [Router] = []
        var pathComponents = PathComponents(request.uri.path ?? "/")
        var pathParameters: [String: String] = [:]
        
        let response = recover(request, visited: &visited) { visited in
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
            
            while let router = visited.popLast() {
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
            
            if let representable = lastError as? ResponseRepresentable {
                Logger.error("Error can be represented as a response. Recovering.", error: lastError)
                return representable.response
            }
            
            Logger.error("Unrecovered error while processing request.")
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
    public func add(_ path: PathComponent..., router: Router) {
        _add(path, router: router)
    }
    
    internal func _add(_ path: [PathComponent], router: Router) {
        var path = path
        
        guard !path.isEmpty else {
            return copy(router)
        }
        
        guard path.count > 1  else {
            switch path[0] {
            case let .subpath(subpath):
                return subrouters[subpath] = router
            case let .parameter(parameter):
                return pathParameterSubrouter = (parameter, router)
            }
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter._add(path, router: router)
    }
}


extension Router {
    public func preprocess(_ path: PathComponent..., body: @escaping Preprocess) {
        _preprocess(path as [PathComponent], body: body)
    }
    
    private func _preprocess(_ path: [PathComponent], body: @escaping Preprocess) {
        var path = path
        
        guard !path.isEmpty else {
            return preprocess = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter._preprocess(path, body: body)
    }
}

extension Router {
    public func postprocess(_ path: PathComponent..., body: @escaping Postprocess) {
        _postprocess(path as [PathComponent], body: body)
    }
    
    private func _postprocess(_ path: [PathComponent], body: @escaping Postprocess) {
        var path = path
        
        guard !path.isEmpty else {
            return postprocess = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter._postprocess(path, body: body)
    }
}

extension Router {
    public func recover(_ path: PathComponent..., body: @escaping Recover) {
        _recover(path as [PathComponent], body: body)
    }
    
    private func _recover(_ path: [PathComponent], body: @escaping Recover) {
        var path = path
        
        guard !path.isEmpty else {
            return recover = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter._recover(path, body: body)
    }
}

extension Router {
    public func get(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .get, path: path as [PathComponent], body: body)
    }
    
    public func post(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .post, path: path as [PathComponent], body: body)
    }
    
    public func put(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .put, path: path as [PathComponent], body: body)
    }
    
    public func patch(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .patch, path: path as [PathComponent], body: body)
    }
    
    public func delete(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .delete, path: path as [PathComponent], body: body)
    }
    
    public func head(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .head, path: path as [PathComponent], body: body)
    }
    
    public func options(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .options, path: path as [PathComponent], body: body)
    }
    
    public func trace(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .trace, path: path as [PathComponent], body: body)
    }
    
    public func connect(_ path: PathComponent..., body: @escaping Respond) {
        _respond(to: .connect, path: path as [PathComponent], body: body)
    }
    
    public func respond(
        to method: Request.Method,
        path: PathComponent...,
        body: @escaping Respond
    ) {
        _respond(to: method, path: path as [PathComponent], body: body)
    }
    
    private func _respond(
        to method: Request.Method,
        path: [PathComponent],
        body: @escaping Respond
    ) {
        var path = path
        
        guard !path.isEmpty else {
            return responders[method] = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter._respond(to: method, path: path, body: body)
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

extension Router {
    fileprivate func getSubrouter(_ pathComponent: PathComponent, path: String) -> Router {
        switch pathComponent {
        case let .subpath(subpath):
            guard let subouter = subrouters[subpath] else {
                let router = Router()
                add(pathComponent, router: router)
                return router
            }
            
            subrouters[subpath] = subouter
            return subouter
        case let .parameter(parameter):
            guard let (subouterParameter, subouter) = pathParameterSubrouter else {
                let router = Router()
                add(pathComponent, router: router)
                return router
            }
            
            Logger.warning("Overwriting parameter \(subouterParameter) with parameter \(parameter) in route \(path)")
            
            pathParameterSubrouter = (parameter, subouter)
            return subouter
        }
    }
}










