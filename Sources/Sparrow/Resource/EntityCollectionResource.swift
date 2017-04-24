import HTTP
import Core

public enum EntityCollectionResourceResultKey: String {
    case entities
    case count
    case metadata
    case limit
    case offset
    case total
}

public struct EntityCollectionResourceResult<T: ContentRepresentable> {
    fileprivate let entities: [T]
    fileprivate let total: Int

    public init(entities: [T], ofTotal total: Int) {
        self.entities = entities
        self.total = total
    }
}

public protocol EntityCollectionResource: Resource {
    associatedtype Entity: ContentConvertible

    /// Configure the keys in the returning response
    ///
    /// - Parameter key: Key to transform
    /// - Returns: String to use in the returning response
    static func resultKey(for key: EntityCollectionResourceResultKey) -> String

    /// Lists all entities
    ///
    /// - Parameters:
    ///   - offset: Index offsetting the returning range of entities
    ///   - limit: Limit the returning range of entities
    func list(offset: Int, limit: Int?) throws -> EntityCollectionResourceResult<Entity>

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

extension EntityCollectionResource {

    public static func resultKey(for key: EntityCollectionResourceResultKey) -> String {
        return key.rawValue
    }

    public func get(context: RequestContext) throws -> ResponseContext {

        let offset: Int = try context.queryParameters.value(for: "offset") ?? 0

        let result = try list(
            offset: offset,
            limit: context.queryParameters.value(for: "limit")
        )
        return ResponseContext(
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

    public func post(context: RequestContext) throws -> ResponseContext {
        return try ResponseContext(
            status: .created,
            content: create(element: Entity(content: context.content))
        )
    }

    public func delete(context: RequestContext) throws -> ResponseContext {
        try deleteAll()
        return ResponseContext(status: .ok)
    }
}

extension EntityCollectionResource {

    public func create(element: Entity) throws -> Entity {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func deleteAll() throws {
        throw HTTPError(error: .methodNotAllowed)
    }
}
