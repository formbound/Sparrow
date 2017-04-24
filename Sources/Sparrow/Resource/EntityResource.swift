import Core
import HTTP

public protocol EntityResource: ParameterResource {
    associatedtype Entity: ContentConvertible
    associatedtype Identifier: ParameterInitializable

    func show(identifier: Identifier) throws -> Entity?

    func delete(identifier: Identifier) throws

    func replace(identifier: Identifier, with entity: Entity) throws -> Entity

    func update(identifier: Identifier, with content: Content) throws -> Entity

}

extension EntityResource {

    public func get(context: RequestContext, parameter: Identifier) throws -> ResponseContext {

        guard let entity: Entity = try show(identifier: parameter) else {
            throw HTTPError(error: .notFound)
        }

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }

    public func delete(context: RequestContext, parameter: Identifier) throws -> ResponseContext {
        try delete(identifier: parameter)

        return ResponseContext(
            status: .ok
        )
    }

    public func put(context: RequestContext, parameter: Identifier) throws -> ResponseContext {
        let entity = try replace(identifier: parameter, with: Entity(content: context.content))

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }

    public func patch(context: RequestContext, parameter: Identifier) throws -> ResponseContext {
        let entity = try update(identifier: parameter, with: context.content)

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
