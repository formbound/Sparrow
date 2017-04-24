import Core
import HTTP

public protocol EntityResource: PathParameterResource {
    associatedtype Entity: ContentConvertible
    associatedtype Identifier: ParameterInitializable

    func show(identifier: Identifier) throws -> Entity?

    func delete(identifier: Identifier) throws

    func replace(identifier: Identifier, with entity: Entity) throws -> Entity

    func update(identifier: Identifier, with content: Content) throws -> Entity

}

extension EntityResource {

    public func get(context: RequestContext, pathParameter: Identifier) throws -> ResponseContext {

        guard let entity: Entity = try show(identifier: pathParameter) else {
            throw HTTPError(error: .notFound)
        }

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }

    public func delete(context: RequestContext, pathParameter: Identifier) throws -> ResponseContext {
        try delete(identifier: pathParameter)

        return ResponseContext(
            status: .ok
        )
    }

    public func put(context: RequestContext, pathParameter: Identifier) throws -> ResponseContext {
        let entity = try replace(identifier: pathParameter, with: Entity(content: context.content))

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }

    public func patch(context: RequestContext, pathParameter: Identifier) throws -> ResponseContext {
        let entity = try update(identifier: pathParameter, with: context.content)

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }
}

extension EntityResource {
    public func delete(identifier: Identifier) throws {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func replace(identifier: Identifier, with entity: Entity) throws -> Entity {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func update(identifier: Identifier, with content: Content) throws -> Entity {
        throw HTTPError(error: .methodNotAllowed)
    }
}
