import HTTP



public protocol Resource {

    func delete(context: RequestContext) throws -> ResponseContext

    func get(context: RequestContext) throws -> ResponseContext

    func head(context: RequestContext) throws -> ResponseContext

    func post(context: RequestContext) throws -> ResponseContext

    func put(context: RequestContext) throws -> ResponseContext

    func options(context: RequestContext) throws -> ResponseContext

    func patch(context: RequestContext) throws -> ResponseContext
}

extension Resource {
    internal func makeRouter(pathComponent: Router.PathComponent) -> Router {
        let router = Router()

        router.respond(to: .delete, handler: delete)
        router.respond(to: .get, handler: get)
        router.respond(to: .head, handler: head)
        router.respond(to: .post, handler: post)
        router.respond(to: .put, handler: put)
        router.respond(to: .options, handler: options)
        router.respond(to: .patch, handler: patch)

        return router
    }
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

    public func options(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func patch(context: RequestContext) throws -> ResponseContext {
        throw HTTPError(error: .methodNotAllowed)
    }
}
