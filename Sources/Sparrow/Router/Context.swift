public enum RoutingContextError : Error {
    case pathComponentNotFound
    case cannotInitializePathComponent(string: String)
    case valueNotFound(key: String)
    case incompatibleType(requestedType: Any.Type, actualType: Any.Type)
}

public class ContextStorage {
    var pathComponents: [String: String]
    var values: [String: Any]

    public init() {
        pathComponents = [:]
        values = [:]
    }
}

public protocol RoutingContext: class {
    associatedtype Application
    var storage: ContextStorage { get }

    init(application: Application)
}

extension RoutingContext {

    public func set(_ value: Any?, key: String) {
        storage.values[key] = value
    }

    public func get<T>(_ key: String) throws -> T {
        guard let value = storage.values[key] else  {
            throw RoutingContextError.valueNotFound(key: key)
        }

        guard let castedValue = value as? T else {
            throw RoutingContextError.incompatibleType(requestedType: T.self, actualType: type(of: value))
        }

        return castedValue
    }

    public func pathComponent<Component :  RouteComponent>(for component: Component.Type) throws -> String {
        guard let pathComponent = storage.pathComponents[component.pathComponentKey] else {
            throw RoutingContextError.pathComponentNotFound
        }

        return pathComponent
    }

    public func pathComponent<Component :  RouteComponent, P : LosslessStringConvertible>(
        for component: Component.Type
        ) throws -> P {
        let string = try pathComponent(for: component)

        guard let pathComponent = P(string) else {
            throw RoutingContextError.cannotInitializePathComponent(string: string)
        }

        return pathComponent
    }
}
