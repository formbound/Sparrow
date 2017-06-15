import Zewo

public enum ContextError : Error {
    case pathComponentNotFound(component: RouteComponent.Type)
    case cannotInitializePathComponent(string: String)
    case valueNotFound(key: String)
    case incompatibleType(requestedType: Any.Type, actualType: Any.Type)
}

open class Context {
    var pathComponents: [String: String] = [:]
    var storage: [String: Any] = [:]
    
    public init() {}
    
    public func pathComponent<Component :  RouteComponent>(for component: Component.Type) throws -> String {
        guard let pathComponent = pathComponents[component.pathComponentKey] else {
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
    
    public func set(_ value: Any?, key: String) {
        storage[key] = value
    }
    
    public func get<T>(_ key: String) throws -> T {
        guard let value = storage[key] else  {
            throw ContextError.valueNotFound(key: key)
        }
        
        guard let castedValue = value as? T else {
            throw ContextError.incompatibleType(requestedType: T.self, actualType: type(of: value))
        }
        
        return castedValue
    }
}

public enum PathComponent {
    case path(String)
    case wildcard
}

extension PathComponent : Hashable {
    public var hashValue: Int {
        switch self {
        case .wildcard:
            return "".hashValue
        case .path(let string):
            return string.hashValue
        }
    }
    
    public static func ==(lhs: PathComponent, rhs: PathComponent) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension PathComponent : ExpressibleByStringLiteral {
    /// :nodoc:
    public init(unicodeScalarLiteral value: String) {
        self = .path(value)
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .path(value)
    }
    
    /// :nodoc:
    public init(stringLiteral value: StringLiteralType) {
        self = .path(value)
    }
}

public protocol RouteComponent {
    var children: [PathComponent: RouteComponent] { get }
    
    func preprocess(request: Request, context: Context) throws
    func postprocess(response: Response, for request: Request, context: Context) throws
    func recover(error: Error, for request: Request, context: Context) throws -> Response
}

public protocol GetResponder {
    func get(request: Request, context: Context) throws -> Response
}

public protocol PostResponder {
    func post(request: Request, context: Context) throws -> Response
}

public protocol PutResponder {
    func put(request: Request, context: Context) throws -> Response
}

public protocol PatchResponder {
    func patch(request: Request, context: Context) throws -> Response
}

public protocol DeleteResponder {
    func delete(request: Request, context: Context) throws -> Response
}

public protocol HeadResponder {
    func head(request: Request, context: Context) throws -> Response
}

public protocol OptionsResponder {
    func options(request: Request, context: Context) throws -> Response
}

public protocol TraceResponder {
    func trace(request: Request, context: Context) throws -> Response
}

public protocol ConnectResponder {
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
    public func preprocess(request: Request, context: Context) throws {}

    public var children: [PathComponent: RouteComponent] {
        return [:]
    }
    
    public func postprocess(response: Response, for request: Request, context: Context) throws {}
    
    public func recover(error: Error, for request: Request, context: Context) throws -> Response {
        throw error
    }
}

extension RouteComponent {
    internal func child(for pathComponent: String) -> RouteComponent? {
        let named: [String: RouteComponent] = children.reduce([:]) {
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
        case .get:
            guard let responder = self as? GetResponder else {
                fallthrough
            }
            
            return responder.get
        case .post:
            guard let responder = self as? PostResponder else {
                fallthrough
            }
            
            return responder.post
        case .put:
            guard let responder = self as? PutResponder else {
                fallthrough
            }
            
            return responder.put
        case .patch:
            guard let responder = self as? PatchResponder else {
                fallthrough
            }
            
            return responder.patch
        case .delete:
            guard let responder = self as? DeleteResponder else {
                fallthrough
            }
            
            return responder.delete
        case .head:
            guard let responder = self as? HeadResponder else {
                fallthrough
            }
            
            return responder.head
        case .options:
            guard let responder = self as? OptionsResponder else {
                fallthrough
            }
            
            return responder.options
        case .trace:
            guard let responder = self as? TraceResponder else {
                fallthrough
            }
            
            return responder.trace
        case .connect:
            guard let responder = self as? ConnectResponder else {
                fallthrough
            }
            
            return responder.connect
        default: throw RouterError.methodNotAllowed
        }
    }
}
