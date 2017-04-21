import HTTP

public protocol Resource {

    func delete(context: RequestContext) throws -> Payload

    func get(context: RequestContext) throws -> Payload

    func head(context: RequestContext) throws -> Payload

    func post(context: RequestContext) throws -> Payload

    func put(context: RequestContext) throws -> Payload

    func connect(context: RequestContext) throws -> Payload

    func options(context: RequestContext) throws -> Payload

    func trace(context: RequestContext) throws -> Payload

    func patch(context: RequestContext) throws -> Payload

    func other(method: String, context: RequestContext) throws -> Payload
}

extension Resource {
    internal func respond(to context: RequestContext) throws -> Payload {
        switch context.request.method {
        case .delete:
            return try delete(context: context)
        case .get:
            return try get(context: context)

        case .head:
            return try head(context: context)

        case .post:
            return try post(context: context)

        case .put:
            return try put(context: context)

        case .connect:
            return try connect(context: context)

        case .options:
            return try options(context: context)

        case .trace:
            return try trace(context: context)

        case .patch:
            return try patch(context: context)

        case .other(let method):
            return try other(method: method, context: context)
        }
    }

    internal func add(to router: Router, pathComponent: String) {

        router.add(pathComponent: pathComponent) { router in

            router.respond(to: .delete, handler: delete(context:))
            router.respond(to: .get, handler: get(context:))
            router.respond(to: .head, handler: head(context:))
            router.respond(to: .post, handler: post(context:))
            router.respond(to: .put, handler: put(context:))
            router.respond(to: .connect, handler: connect(context:))
            router.respond(to: .options, handler: options(context:))
            router.respond(to: .trace, handler: trace(context:))
            router.respond(to: .patch, handler: patch(context:))

        }

    }
}

extension Resource {

    func delete(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func get(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func head(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func post(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func put(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func connect(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func options(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func trace(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func patch(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    func other(method: String, context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }
}
