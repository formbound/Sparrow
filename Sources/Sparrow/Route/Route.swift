import Core
import HTTP
import Venice

public struct RouteConfiguration {
    private let router: Router
    
    fileprivate init(_ router: Router) {
        self.router = router
    }
    
    public func add<R : Route>(route: R, subpath: String) {
        router.add(subpath: subpath, body: route.build(router:))
    }
    
    public func add<R : Route>(route: R, parameter: String) {
        router.add(parameter: parameter, body: route.build(router:))
    }
    
    public func respond(method: Method, body: @escaping Router.Respond) {
        router.respond(method: method, body: body)
    }
}

public protocol Route {
    static var key: String { get }
    
    func configure(route: RouteConfiguration)
    
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
    
    func recover(error: Error) throws -> Response
}

public extension Route {
    static var key: String {
        return String(describing: Self.self)
    }
    
    func configure(route: RouteConfiguration) {}
    
    func preprocess(request: Request) throws {}
    
    func get(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func post(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func put(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func patch(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func delete(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func head(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func options(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func trace(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func connect(request: Request) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    func postprocess(response: Response, for request: Request) throws {}
    
    func recover(error: Error) throws -> Response {
        throw error
    }
}

extension Route {
    fileprivate func build(router: Router) {
        configure(route: RouteConfiguration(router))
        router.preprocess(body: preprocess(request:))
        router.respond(method: .get, body: get(request:))
        router.respond(method: .post, body: post(request:))
        router.respond(method: .put, body: put(request:))
        router.respond(method: .patch, body: patch(request:))
        router.respond(method: .delete, body: delete(request:))
        router.respond(method: .head, body: delete(request:))
        router.respond(method: .options, body: delete(request:))
        router.respond(method: .trace, body: delete(request:))
        router.respond(method: .connect, body: connect(request:))
        router.postprocess(body: postprocess(response:for:))
        router.recover(body: recover(error:))
    }
}

public extension Router {
    convenience init(root: Route) {
        self.init()
        root.build(router: self)
    }
}
