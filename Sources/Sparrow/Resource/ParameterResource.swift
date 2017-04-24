import HTTP

public protocol ParameterResource: Resource {
    associatedtype Parameter: ParameterInitializable

    func delete(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func get(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func head(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func post(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func put(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func connect(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func options(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func trace(context: RequestContext, parameter: Parameter) throws -> ResponseContext

    func patch(context: RequestContext, parameter: Parameter) throws -> ResponseContext
}

extension ParameterResource {

    public func delete(context: RequestContext) throws -> ResponseContext {
        return try delete(context: context, parameter: try context.pathParameter())
    }

    public func get(context: RequestContext) throws -> ResponseContext {
        return try get(context: context, parameter: try context.pathParameter())
    }
    public func head(context: RequestContext) throws -> ResponseContext {
        return try head(context: context, parameter: try context.pathParameter())
    }

    public func post(context: RequestContext) throws -> ResponseContext {
        return try post(context: context, parameter: try context.pathParameter())
    }

    public func put(context: RequestContext) throws -> ResponseContext {
        return try put(context: context, parameter: try context.pathParameter())
    }

    public func connect(context: RequestContext) throws -> ResponseContext {
        return try connect(context: context, parameter: try context.pathParameter())
    }

    public func options(context: RequestContext) throws -> ResponseContext {
        return try options(context: context, parameter: try context.pathParameter())
    }

    public func trace(context: RequestContext) throws -> ResponseContext {
        return try trace(context: context, parameter: try context.pathParameter())
    }

    public func patch(context: RequestContext) throws -> ResponseContext {
        return try patch(context: context, parameter: try context.pathParameter())
    }
}

extension ParameterResource {

    public func delete(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func get(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func head(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func post(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func put(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func connect(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func options(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func trace(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func patch(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }
}
