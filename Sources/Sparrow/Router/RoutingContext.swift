public protocol RoutingContext : class {
    associatedtype Application
    
    var storage: ContextStorage { get }

    init(application: Application)
}

extension RoutingContext {
    public func parameter(forKey key: RouteComponentKey) throws -> String {
        guard let pathComponent = storage.parameters[key] else {
            throw RouterError.parameterNotFound
        }

        return pathComponent
    }

    public func parameter<PathComponent : LosslessStringConvertible>(
        forKey key: RouteComponentKey
    ) throws -> PathComponent {
        let pathComponentString = try parameter(forKey: key)

        guard let pathComponent = PathComponent(pathComponentString) else {
            throw RouterError.cannotInitializeParameter(pathComponent: pathComponentString)
        }

        return pathComponent
    }
}

public final class Context : RoutingContext {
    public let storage = ContextStorage()
    public init(application: Void) {}
}
