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

    public func get(request: Request) throws -> Response {

        guard let entity: Entity = try show(
            pathParameters: PathParameters(parameters: request.pathParameters),
            queryItems: request.queryParameters
        ) else {
            throw HTTPError(error: .methodNotAllowed)
        }

        return Response(
            status: .ok,
            content: entity
        )
    }

    public func delete(request: Request) throws -> Response {
        try delete(
            pathParameters: PathParameters(parameters: request.pathParameters),
            queryItems: request.queryParameters
        )

        return Response(
            status: .ok
        )
    }

    public func put(request: Request) throws -> Response {
        let entity = try replace(
            pathParameters: PathParameters(parameters: request.pathParameters),
            queryItems: request.queryParameters,
            with: Entity(content: request.content
            )
        )

        return Response(
            status: .ok,
            content: entity
        )
    }

    public func patch(request: Request) throws -> Response {
        let entity = try update(
            pathParameters: PathParameters(parameters: request.pathParameters),
            queryItems: request.queryParameters,
            with: request.content
        )

        return Response(
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
