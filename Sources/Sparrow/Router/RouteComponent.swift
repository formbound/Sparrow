import Zewo

public protocol RouteComponent {
    var pathParameterChild: RouteComponent { get }
    static var pathParameterKey: String { get }
    
    var children: [String: RouteComponent] { get }
    
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

struct NoPathParameterChild : RouteComponent {
    var pathParameterChild: RouteComponent {
        return self
    }
}

public extension RouteComponent {
    public var pathParameterChild: RouteComponent {
        return NoPathParameterChild()
    }
    
    public static var pathParameterKey: String {
        return String(describing: Self.self).camelCaseSplit().map { word in
            word.lowercased()
        }.joined(separator: "-")
    }
    
    public func preprocess(request: Request) throws {}

    public var children: [String: RouteComponent] {
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
