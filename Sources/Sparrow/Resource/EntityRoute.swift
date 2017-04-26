import Core
import HTTP

public protocol EntityRoute: Route {
    associatedtype Entity: ContentConvertible
    associatedtype PathParameters: ParametersInitializable

    func show(pathParameters: PathParameters, queryItems: Parameters) throws -> Entity?

    func delete(pathParameters: PathParameters, queryItems: Parameters) throws

    func replace(pathParameters: PathParameters, queryItems: Parameters, with entity: Entity) throws -> Entity

    func update(pathParameters: PathParameters, queryItems: Parameters, with content: Content) throws -> Entity

}

extension EntityRoute {

    public func get(context: RequestContext) throws -> ResponseContext {

        guard let entity: Entity = try show(
            pathParameters: PathParameters(parameters: context.pathParameters),
            queryItems: context.queryParameters
        ) else {
            throw HTTPError(error: .methodNotAllowed)
        }

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }

    public func delete(context: RequestContext) throws -> ResponseContext {
        try delete(
            pathParameters: PathParameters(parameters: context.pathParameters),
            queryItems: context.queryParameters
        )

        return ResponseContext(
            status: .ok
        )
    }

    public func put(context: RequestContext) throws -> ResponseContext {
        let entity = try replace(
            pathParameters: PathParameters(parameters: context.pathParameters),
            queryItems: context.queryParameters,
            with: Entity(content: context.content
            )
        )

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }

    public func patch(context: RequestContext) throws -> ResponseContext {
        let entity = try update(
            pathParameters: PathParameters(parameters: context.pathParameters),
            queryItems: context.queryParameters,
            with: context.content
        )

        return ResponseContext(
            status: .ok,
            content: entity
        )
    }
}

extension EntityRoute {
    public func delete(pathParameters: PathParameters, queryItems: Parameters) throws {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func replace(pathParameters: PathParameters, queryItems: Parameters, with entity: Entity) throws -> Entity {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func update(pathParameters: PathParameters, queryItems: Parameters, with content: Content) throws -> Entity {
        throw HTTPError(error: .methodNotAllowed)
    }
}
