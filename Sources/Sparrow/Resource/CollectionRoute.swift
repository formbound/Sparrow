import HTTP
import Core

public enum CollectionRouteResultKey: String {
    case entities
    case count
    case metadata
    case limit
    case offset
    case total
}

public struct CollectionRouteResult<T: ContentRepresentable> {
    fileprivate let entities: [T]
    fileprivate let total: Int

    public init(entities: [T], ofTotal total: Int) {
        self.entities = entities
        self.total = total
    }
}

public protocol CollectionRoute: Route {
    associatedtype Entity: ContentConvertible

    /// Configure the keys in the returning response
    ///
    /// - Parameter key: Key to transform
    /// - Returns: String to use in the returning response
    static func resultKey(for key: CollectionRouteResultKey) -> String

    /// Lists all entities
    ///
    /// - Parameters:
    ///   - offset: Index offsetting the returning range of entities
    ///   - limit: Limit the returning range of entities
    func list(offset: Int, limit: Int?) throws -> CollectionRouteResult<Entity>

    /// Creates a new entity
    ///
    /// Note: Default implementation returns 405 Method not allowed
    ///
    /// - Parameter element: Entity to create, parsed from the request body
    /// - Returns: The newly created entity, optionally modified by this action
    func create(element: Entity) throws -> Entity

    /// Delete all entities
    ///
    /// Note: Default implementation returns 405 Method not allowed
    func deleteAll() throws
}

extension CollectionRoute {

    public static func resultKey(for key: CollectionRouteResultKey) -> String {
        return key.rawValue
    }

    public func get(request: Request) throws -> Response {

        let offset: Int = try request.queryParameters.get("offset") ?? 0

        let result = try list(
            offset: offset,
            limit: request.queryParameters.get("limit")
        )
        return Response(
            status: .ok,
            content: Content(
                dictionary: [
                    Self.resultKey(for: .entities): Content(array: result.entities),
                    Self.resultKey(for: .metadata): Content(
                        dictionary: [
                            Self.resultKey(for: .count): result.entities.count,
                            Self.resultKey(for: .total): result.total,
                            Self.resultKey(for: .offset): offset
                        ])
                ])
        )
    }

    public func post(request: Request) throws -> Response {
        return try Response(
            status: .created,
            content: create(element: Entity(content: request.content))
        )
    }

    public func delete(request: Request) throws -> Response {
        try deleteAll()
        return Response(status: .ok)
    }
}

extension CollectionRoute {

    public func create(element: Entity) throws -> Entity {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func deleteAll() throws {
        throw HTTPError(error: .methodNotAllowed)
    }
}
