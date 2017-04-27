import HTTP

public protocol Route: RequestProcessor {

    func delete(request: Request) throws -> Response

    func get(request: Request) throws -> Response

    func head(request: Request) throws -> Response

    func post(request: Request) throws -> Response

    func put(request: Request) throws -> Response

    func connect(request: Request) throws -> Response

    func options(request: Request) throws -> Response

    func trace(request: Request) throws -> Response

    func patch(request: Request) throws -> Response
}

extension Route {

    public func delete(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func get(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func head(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func post(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func put(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func connect(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func options(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func trace(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }

    public func patch(request: Request) throws -> Response {
        throw HTTPError(error: .methodNotAllowed)
    }
}

extension Route {
    public func preprocess(request: Request) throws {
        return
    }

    public func postprocess(response: Response) throws {
        return
    }
}

