import Zewo

public protocol RouteComponent {
    associatedtype Context : RoutingContext
    
    var children: [PathComponent: AnyRouteComponent<Context>] { get }
    
    func preprocess(request: Request, context: Context) throws
    func postprocess(response: Response, for request: Request, context: Context) throws
    func recover(error: Error, for request: Request, context: Context) throws -> Response
    
    func get(request: Request, context: Context) throws -> Response
    func post(request: Request, context: Context) throws -> Response
    func put(request: Request, context: Context) throws -> Response
    func patch(request: Request, context: Context) throws -> Response
    func delete(request: Request, context: Context) throws -> Response
    func head(request: Request, context: Context) throws -> Response
    func options(request: Request, context: Context) throws -> Response
    func trace(request: Request, context: Context) throws -> Response
    func connect(request: Request, context: Context) throws -> Response
}

extension RouteComponent {
    static var pathComponentKey: String {
        return String(describing: Self.self).camelCaseSplit().map { word in
            word.lowercased()
        }.joined(separator: "-")
    }
}

public extension RouteComponent {
    public var children: [PathComponent: AnyRouteComponent<Context>] {
        return [:]
    }
    
    public func preprocess(request: Request, context: Context) throws {}
    
    public func postprocess(response: Response, for request: Request, context: Context) throws {}
    
    public func recover(error: Error, for request: Request, context: Context) throws -> Response {
        throw error
    }
    
    public func get(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func post(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func put(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func patch(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func delete(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func head(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func options(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func trace(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func connect(request: Request, context: Context) throws -> Response {
        throw RouterError.methodNotAllowed
    }
}

public final class AnyRouteComponent<C : RoutingContext> {
    public typealias Context = C
    
    public var children: [PathComponent : AnyRouteComponent<C>]
    
    let preprocess: (Request, C) throws -> Void
    let postprocess: (Response, Request, C) throws -> Void
    let recover: (Error, Request, C) throws -> Response
    
    let get: (Request, C) throws -> Response
    let post: (Request, C) throws -> Response
    let put: (Request, C) throws -> Response
    let patch: (Request, C) throws -> Response
    let delete: (Request, C) throws -> Response
    let head: (Request, C) throws -> Response
    let options: (Request, C) throws -> Response
    let trace: (Request, C) throws -> Response
    let connect: (Request, C) throws -> Response
    
    let pathComponentKey: String
    
    public init<R : RouteComponent>(_ component: R) where R.Context == C {
        self.children = component.children
        
        self.preprocess = component.preprocess
        self.postprocess = component.postprocess
        self.recover = component.recover
        
        self.get = component.get
        self.post = component.post
        self.put = component.put
        self.patch = component.patch
        self.delete = component.delete
        self.head = component.head
        self.options = component.options
        self.trace = component.trace
        self.connect = component.connect
        
        self.pathComponentKey = R.pathComponentKey
    }
    
    public func preprocess(request: Request, context: C) throws {
        return try preprocess(request, context)
    }
    
    public func postprocess(response: Response, for request: Request, context: C) throws {
        return try postprocess(response, request, context)
    }
    
    public func recover(error: Error, for request: Request, context: C) throws -> Response {
        return try recover(error, request, context)
    }
    
    public func get(request: Request, context: C) throws -> Response {
        return try get(request, context)
    }
    
    public func post(request: Request, context: C) throws -> Response {
        return try post(request, context)
    }
    
    public func put(request: Request, context: C) throws -> Response {
        return try put(request, context)
    }
    
    public func patch(request: Request, context: C) throws -> Response {
        return try patch(request, context)
    }
    
    public func delete(request: Request, context: C) throws -> Response {
        return try delete(request, context)
    }
    
    public func head(request: Request, context: C) throws -> Response {
        return try head(request, context)
    }
    
    public func options(request: Request, context: C) throws -> Response {
        return try options(request, context)
    }
    
    public func trace(request: Request, context: C) throws -> Response {
        return try trace(request, context)
    }
    
    public func connect(request: Request, context: C) throws -> Response {
        return try connect(request, context)
    }
}

extension AnyRouteComponent {
    internal func child(for pathComponent: String) -> AnyRouteComponent<Context>? {
        let named: [String: AnyRouteComponent<Context>] = children.reduce([:]) {
            var dictionary = $0
            
            guard case let .path(path) = $1.key else {
                return dictionary
            }
            
            dictionary[path] = $1.value
            return dictionary
        }
        
        if let component = named[pathComponent] {
            return component
        }
        
        for (pathComponent, component) in children {
            if case .wildcard = pathComponent {
                return component
            }
        }
        
        return nil
    }
    
    internal func responder(for request: Request) throws -> (Request, Context) throws -> Response {
        switch request.method {
        case .get: return get
        case .post: return post
        case .put: return put
        case .patch: return patch
        case .delete: return delete
        case .head: return head
        case .options: return options
        case .trace: return trace
        case .connect: return connect
        default: throw RouterError.methodNotAllowed
        }
    }
}
