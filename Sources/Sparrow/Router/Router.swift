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
    
    internal let logger: Logger
    
    public init(logger: Logger = defaultLogger) {
        self.logger = logger
        configure(router: self)
    }
    
    open func configure(router: Router) {}
    
    internal func add(_ pathComponent: PathComponent) -> Router {
        let subrouter = Router(logger: logger)
        add(pathComponent, subrouter: subrouter)
        return subrouter
    }
    
    public func respond(to request: Request) -> Response {
        do {
            return try process(request: request)
        } catch let error as ResponseRepresentable {
            return error.response
        } catch {
            logger.error("Unrecovered error while processing request.", error: error)
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

        for (key, parameter) in pathParameters {
            request.uri.set(parameter: parameter, for: key)
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
                    return try router.recover(lastError, request)
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
    
    internal static var defaultLogger: Logger {
        return Logger(name: "Router")
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
    public func add(_ path: PathComponent, _ components: PathComponent..., subrouter: Router) {
        var path = [path]
        path.append(contentsOf: components)
        add(path, subrouter: subrouter)
    }
    
    internal func add(_ path: [PathComponent], subrouter: Router) {
        var path = path
        
        guard path.count > 1  else {
            switch path[0] {
            case let .subpath(subpath):
                return subrouters[subpath] = subrouter
            case let .parameter(parameter):
                return pathParameterSubrouter = (parameter, subrouter)
            }
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter.add(path, subrouter: subrouter)
    }
}


extension Router {
    public func preprocess(_ path: PathComponent..., body: @escaping Preprocess) {
        preprocess(path, body: body)
    }
    
    private func preprocess(_ path: [PathComponent], body: @escaping Preprocess) {
        var path = path
        
        guard !path.isEmpty else {
            return preprocess = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter.preprocess(path, body: body)
    }
}

extension Router {
    public func postprocess(_ path: PathComponent..., body: @escaping Postprocess) {
        postprocess(path, body: body)
    }
    
    private func postprocess(_ path: [PathComponent], body: @escaping Postprocess) {
        var path = path
        
        guard !path.isEmpty else {
            return postprocess = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter.postprocess(path, body: body)
    }
}

extension Router {
    public func recover(_ path: PathComponent..., body: @escaping Recover) {
        recover(path, body: body)
    }
    
    private func recover(_ path: [PathComponent], body: @escaping Recover) {
        var path = path
        
        guard !path.isEmpty else {
            return recover = body
        }
        
        let pathComponent = path.removeFirst()
        let subrouter = getSubrouter(pathComponent, path: path.string)
        subrouter.recover(path, body: body)
    }
}

extension Router {
    public func get(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .get, path: path, body: body)
    }
    
    public func post(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .post, path: path, body: body)
    }
    
    public func put(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .put, path: path, body: body)
    }
    
    public func patch(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .patch, path: path, body: body)
    }
    
    public func delete(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .delete, path: path, body: body)
    }
    
    public func head(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .head, path: path, body: body)
    }
    
    public func options(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .options, path: path, body: body)
    }
    
    public func trace(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .trace, path: path, body: body)
    }
    
    public func connect(_ path: PathComponent..., body: @escaping Respond) {
        respond(to: .connect, path: path, body: body)
    }
    
    public func respond(
        to method: Request.Method,
        path: PathComponent...,
        body: @escaping Respond
    ) {
        respond(to: method, path: path, body: body)
    }
    
    private func respond(
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
        subrouter.respond(to: method, path: path, body: body)
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
                return add(pathComponent)
            }
            
            subrouters[subpath] = subouter
            return subouter
        case let .parameter(parameter):
            guard let (subouterParameter, subouter) = pathParameterSubrouter else {
                return add(pathComponent)
            }
            
            logger.warning("Overwriting parameter \(subouterParameter) with parameter \(parameter) in route \(path)")
            
            pathParameterSubrouter = (parameter, subouter)
            return subouter
        }
    }
}










