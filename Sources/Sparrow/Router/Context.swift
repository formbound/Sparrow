public enum RoutingContextError : Error {
    case pathComponentNotFound
    case cannotInitializePathComponent(string: String)
    case valueNotFound(key: String)
    case incompatibleType(requestedType: Any.Type, actualType: Any.Type)
}

public class ContextStorage {
    var pathComponents: [RouteComponentKey: String]
    var values: [String: Any]

    public init() {
        pathComponents = [:]
        values = [:]
    }

    public func set(value: Any?, for key: String) {
        values[key] = value
    }

    public func value<T>(for key: String) throws ->T? {
        guard let value = values[key] else {
            return nil
        }

        guard let cast = value as? T else {
            throw RoutingContextError.incompatibleType(requestedType: T.self, actualType: type(of: value))
        }

        return cast
    }

    public func value<T>(for key: String) throws -> T {
        guard let value = values[key] else {
            throw RoutingContextError.valueNotFound(key: key)
        }

        guard let cast = value as? T else {
            throw RoutingContextError.incompatibleType(requestedType: T.self, actualType: type(of: value))
        }

        return cast
    }
}

public protocol RoutingContext: class {
    associatedtype Application
    var storage: ContextStorage { get }

    init(application: Application)
}

extension RoutingContext {

    public func value(for key: RouteComponentKey) throws -> String {
        guard let pathComponent = storage.pathComponents[key] else {
            throw RoutingContextError.pathComponentNotFound
        }

        return pathComponent
    }

    public func value<P : LosslessStringConvertible>(
        for component: RouteComponentKey
        ) throws -> P {
        let string = try value(for: component)

        guard let pathComponent = P(string) else {
            throw RoutingContextError.cannotInitializePathComponent(string: string)
        }

        return pathComponent
    }
}
