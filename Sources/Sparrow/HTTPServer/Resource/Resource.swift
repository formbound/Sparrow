import HTTP

public protocol Resource {

    func delete(context: RequestContext) throws -> Payload

    func get(context: RequestContext) throws -> Payload

    func head(context: RequestContext) throws -> Payload

    func post(context: RequestContext) throws -> Payload

    func put(context: RequestContext) throws -> Payload

    func options(context: RequestContext) throws -> Payload

    func patch(context: RequestContext) throws -> Payload
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

        case .options:
            return try options(context: context)

        case .patch:
            return try patch(context: context)

        default:
            throw HTTPError(error: .methodNotAllowed)
        }
    }
}

extension Resource {

    public func delete(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func get(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func head(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func post(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func put(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func options(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func patch(context: RequestContext) throws -> Payload {
        throw HTTPError(error: .methodNotAllowed)
    }
}
