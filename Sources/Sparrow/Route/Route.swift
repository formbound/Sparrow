import Core
import HTTP
import Venice

public protocol Route {
    static var key: String { get }
    
    func configure(router: Router)
    
    func preprocess(request: Request) throws
    
    func get(request: Request) throws -> Response
    func post(request: Request) throws -> Response
    func put(request: Request) throws -> Response
    func patch(request: Request) throws -> Response
    func delete(request: Request) throws -> Response
    
    func postprocess(response: Response, for request: Request) throws
    
    func recover(error: Error) throws -> Response
}

public extension Route {
    static var key: String {
        return String(describing: Self.self)
    }
    
    func configure(router: Router) {}
    
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
    
    func postprocess(response: Response, for request: Request) throws {}
    
    func recover(error: Error) throws -> Response {
        throw error
    }
}

extension Route {
    fileprivate func build(router: Router) {
        configure(router: router)
        router.preprocess(body: preprocess(request:))
        router.respond(method: .get, body: get(request:))
        router.respond(method: .post, body: post(request:))
        router.respond(method: .put, body: put(request:))
        router.respond(method: .patch, body: patch(request:))
        router.respond(method: .delete, body: delete(request:))
        router.postprocess(body: postprocess(response:for:))
        router.recover(body: recover(error:))
    }
}

public extension Router {
    convenience init(root: Route) {
        self.init()
        root.build(router: self)
    }
    
    func add<R : Route>(path: String, route: R) {
        add(path: path, body: route.build(router:))
    }
    
    func add<R : Route>(parameter: String, route: R) {
        add(parameter: parameter, body: route.build(router:))
    }
}
