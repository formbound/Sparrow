import Zewo

public protocol RouteComponent {
    associatedtype ComponentContext : RoutingContext = Context
    
    func configure(children: ChildComponents<ComponentContext>)
    
    func preprocess(request: Request, context: ComponentContext) throws
    func postprocess(response: Response, for request: Request, context: ComponentContext) throws
    func recover(error: Error, for request: Request, context: ComponentContext) throws -> Response
    
    func get(request: Request, context: ComponentContext) throws -> Response
    func post(request: Request, context: ComponentContext) throws -> Response
    func put(request: Request, context: ComponentContext) throws -> Response
    func patch(request: Request, context: ComponentContext) throws -> Response
    func delete(request: Request, context: ComponentContext) throws -> Response
    func head(request: Request, context: ComponentContext) throws -> Response
    func options(request: Request, context: ComponentContext) throws -> Response
    func trace(request: Request, context: ComponentContext) throws -> Response
    func connect(request: Request, context: ComponentContext) throws -> Response
}

public extension RouteComponent {
    func configure(children: ChildComponents<ComponentContext>) {}
    
    public func preprocess(request: Request, context: ComponentContext) throws {}
    
    public func postprocess(response: Response, for request: Request, context: ComponentContext) throws {}
    
    public func recover(error: Error, for request: Request, context: ComponentContext) throws -> Response {
        throw error
    }
    
    public func get(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func post(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func put(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func patch(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func delete(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func head(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func options(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func trace(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
    
    public func connect(request: Request, context: ComponentContext) throws -> Response {
        throw RouterError.methodNotAllowed
    }
}
