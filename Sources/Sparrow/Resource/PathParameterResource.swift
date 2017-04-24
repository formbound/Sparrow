import HTTP

public protocol PathParameterResource: Resource {
    associatedtype Parameter: ParameterInitializable

    func delete(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func get(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func head(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func post(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func put(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func connect(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func options(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func trace(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext

    func patch(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext
}

extension PathParameterResource {

    public func delete(context: RequestContext) throws -> ResponseContext {
        return try delete(context: context, pathParameter: try context.pathParameter())
    }

    public func get(context: RequestContext) throws -> ResponseContext {
        return try get(context: context, pathParameter: try context.pathParameter())
    }
    public func head(context: RequestContext) throws -> ResponseContext {
        return try head(context: context, pathParameter: try context.pathParameter())
    }

    public func post(context: RequestContext) throws -> ResponseContext {
        return try post(context: context, pathParameter: try context.pathParameter())
    }

    public func put(context: RequestContext) throws -> ResponseContext {
        return try put(context: context, pathParameter: try context.pathParameter())
    }

    public func connect(context: RequestContext) throws -> ResponseContext {
        return try connect(context: context, pathParameter: try context.pathParameter())
    }

    public func options(context: RequestContext) throws -> ResponseContext {
        return try options(context: context, pathParameter: try context.pathParameter())
    }

    public func trace(context: RequestContext) throws -> ResponseContext {
        return try trace(context: context, pathParameter: try context.pathParameter())
    }

    public func patch(context: RequestContext) throws -> ResponseContext {
        return try patch(context: context, pathParameter: try context.pathParameter())
    }
}

extension PathParameterResource {

    public func delete(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func get(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func head(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func post(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func put(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func connect(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func options(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func trace(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func patch(context: RequestContext, pathParameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }
}
