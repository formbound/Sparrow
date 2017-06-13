import Core
@_exported import HTTP
import Venice

public protocol Route {
    
    var children: [PathComponent: Route] { get }
    
    func preprocess(request: Request) throws
    
    func get(request: Request) throws -> Response

    func post(request: Request) throws -> Response

    func put(request: Request) throws -> Response

    func patch(request: Request) throws -> Response

    func delete(request: Request) throws -> Response
    
    func head(request: Request) throws -> Response

    func options(request: Request) throws -> Response

    func trace(request: Request) throws -> Response

    func connect(request: Request) throws -> Response
    
    func postprocess(response: Response, for request: Request) throws
    
    func recover(error: Error, for request: Request) throws -> Response
}

public extension Route {

    public func preprocess(request: Request) throws {}

    public var children: [PathComponent: Route] {
        return [:]
    }
    
    public func get(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func post(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func put(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func patch(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func delete(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func head(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func options(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func trace(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func connect(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func postprocess(response: Response, for request: Request) throws {}
    
    public func recover(error: Error, for request: Request) throws -> Response {
        throw error
    }
}
