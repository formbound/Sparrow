import HTTP

public protocol Resource {

    func delete(context: RequestContext) throws -> ResponseContext

    func get(context: RequestContext) throws -> ResponseContext

    func head(context: RequestContext) throws -> ResponseContext

    func post(context: RequestContext) throws -> ResponseContext

    func put(context: RequestContext) throws -> ResponseContext

    func connect(context: RequestContext) throws -> ResponseContext

    func options(context: RequestContext) throws -> ResponseContext

    func trace(context: RequestContext) throws -> ResponseContext

    func patch(context: RequestContext) throws -> ResponseContext
}

extension Resource {

    public func delete(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func get(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func head(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func post(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func put(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func connect(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func options(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func trace(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func patch(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }
}
