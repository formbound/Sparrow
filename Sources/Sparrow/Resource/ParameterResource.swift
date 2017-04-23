import HTTP

public protocol ParameterResource {
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

    func other(context: RequestContext, parameter: Parameter) throws -> ResponseContext
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

    public func other(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    internal func respond(context: RequestContext, parameter: Parameter) throws -> ResponseContext {
        switch context.request.method {
        case .delete:
            return try delete(context: context, parameter: parameter)

        case .get:
            return try get(context: context, parameter: parameter)

        case .head:
            return try head(context: context, parameter: parameter)

        case .post:
            return try post(context: context, parameter: parameter)

        case .put:
            return try put(context: context, parameter: parameter)

        case .connect:
            return try connect(context: context, parameter: parameter)

        case .options:
            return try options(context: context, parameter: parameter)

        case .trace:
            return try trace(context: context, parameter: parameter)

        case .patch:
            return try patch(context: context, parameter: parameter)

        case .other:
            return try other(context: context, parameter: parameter)
        }
    }
}
