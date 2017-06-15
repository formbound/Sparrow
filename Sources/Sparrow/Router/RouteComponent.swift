import Zewo

public enum ContextError : Error {
    case pathComponentNotFound(component: RouteComponent.Type)
    case cannotInitializePathComponent(string: String)
}

open class Context {
    public var parameters: [String: String] = [:]
    
    public init() {}
    
    public func pathComponent<Component :  RouteComponent>(for component: Component.Type) throws -> String {
        guard let pathComponent = parameters[component.pathParameterKey] else {
            throw ContextError.pathComponentNotFound(component: component)
        }
        
        return pathComponent
    }
    
    public func pathComponent<Component :  RouteComponent, P : LosslessStringConvertible>(
        for component: Component.Type
    ) throws -> P {
        let string = try pathComponent(for: component)
        
        guard let pathComponent = P(string) else {
            throw ContextError.cannotInitializePathComponent(string: string)
        }
        
        return pathComponent
    }
}

public protocol RouteComponent {
    var pathParameterChild: RouteComponent { get }
    static var pathParameterKey: String { get }
    
    var children: [String: RouteComponent] { get }
    
    func preprocess(request: Request, context: Context) throws
    func get(request: Request, context: Context) throws -> Response
    func post(request: Request, context: Context) throws -> Response
    func put(request: Request, context: Context) throws -> Response
    func patch(request: Request, context: Context) throws -> Response
    func delete(request: Request, context: Context) throws -> Response
    func head(request: Request, context: Context) throws -> Response
    func options(request: Request, context: Context) throws -> Response
    func trace(request: Request, context: Context) throws -> Response
    func connect(request: Request, context: Context) throws -> Response
    func postprocess(response: Response, for request: Request, context: Context) throws
    func recover(error: Error, for request: Request, context: Context) throws -> Response
}

struct NoPathParameterChild : RouteComponent {
    var pathParameterChild: RouteComponent {
        return self
    }
}

public extension RouteComponent {
    public var pathParameterChild: RouteComponent {
        return NoPathParameterChild()
    }
    
    public static var pathParameterKey: String {
        return String(describing: Self.self).camelCaseSplit().map { word in
            word.lowercased()
        }.joined(separator: "-")
    }
    
    public func preprocess(request: Request, context: Context) throws {}

    public var children: [String: RouteComponent] {
        return [:]
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
    
    public func postprocess(response: Response, for request: Request, context: Context) throws {}
    
    public func recover(error: Error, for request: Request, context: Context) throws -> Response {
        throw error
    }
}

extension RouteComponent {
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
