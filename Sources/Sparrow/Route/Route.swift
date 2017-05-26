import Core
import HTTP
import Venice

public struct RouteConfiguration {
    private let router: Router
    
    fileprivate init(_ router: Router) {
        self.router = router
    }
    
    public func add<R : Route>(_ path: PathComponent..., subroute: R) {
        let subrouter = Router()
        subroute.build(router: subrouter)
        router._add(path as [PathComponent], router: subrouter)
    }
}

public protocol Route {
    static var parameter: PathComponent { get }
    static var parameterKey: String { get }
    
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
    
    func recover(error: Error, for request: Request) throws -> Response
}

public extension Route {
    static var parameter: PathComponent {
        return .parameter(Self.parameterKey)
    }
    
    static var parameterKey: String {
        var key: String = ""
        
        for (index, character) in String(describing: Self.self).characters.enumerated() {
            if index != 0, "A"..."Z" ~= character {
                key.append("-")
            }
            
            key.append(character)
        }
        
        return key.lowercased()
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
    
    func recover(error: Error, for request: Request) throws -> Response {
        throw error
    }
}

extension Route {
    fileprivate func build(router: Router) {
        configure(route: RouteConfiguration(router))
        router.preprocess(body: preprocess(request:))
        router.respond(to: .get, body: get(request:))
        router.respond(to: .post, body: post(request:))
        router.respond(to: .put, body: put(request:))
        router.respond(to: .patch, body: patch(request:))
        router.respond(to: .delete, body: delete(request:))
        router.respond(to: .head, body: delete(request:))
        router.respond(to: .options, body: delete(request:))
        router.respond(to: .trace, body: delete(request:))
        router.respond(to: .connect, body: connect(request:))
        router.postprocess(body: postprocess(response:for:))
        router.recover(body: recover(error:for:))
    }
}

public extension Router {
    convenience init(root: Route) {
        self.init()
        root.build(router: self)
    }
    
    public func add(_ path: PathComponent..., route: Route) {
        let router = Router()
        route.build(router: router)
        _add(path as [PathComponent], router: router)
    }
}
