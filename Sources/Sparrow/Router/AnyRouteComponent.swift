internal final class AnyRouteComponent<Context : RoutingContext> {
    typealias ComponentRoutingContext = Context
    
    var pathComponentStrategyChildren: [String: (RouteComponentKey, AnyRouteComponent<Context>)]
    var parameterStrategyChild: (LosslessStringConvertible.Type, RouteComponentKey, AnyRouteComponent<Context>)?
    
    let preprocess: (Request, Context) throws -> Void
    let postprocess: (Response, Request, Context) throws -> Void
    let recover: (Error, Request, Context) throws -> Response
    
    let get: (Request, Context) throws -> Response
    let post: (Request, Context) throws -> Response
    let put: (Request, Context) throws -> Response
    let patch: (Request, Context) throws -> Response
    let delete: (Request, Context) throws -> Response
    let head: (Request, Context) throws -> Response
    let options: (Request, Context) throws -> Response
    let trace: (Request, Context) throws -> Response
    let connect: (Request, Context) throws -> Response
    
    init<Component : RouteComponent>(
        _ component: Component
    ) where Component.ComponentContext == Context {
        let children = ChildComponents<Context>()
        component.configure(children: children)
        
        self.pathComponentStrategyChildren = children.pathComponentStrategyChildren
        self.parameterStrategyChild = children.parameterStrategyChild
        
        self.preprocess = component.preprocess
        self.postprocess = component.postprocess
        self.recover = component.recover
        
        self.get = component.get
        self.post = component.post
        self.put = component.put
        self.patch = component.patch
        self.delete = component.delete
        self.head = component.head
        self.options = component.options
        self.trace = component.trace
        self.connect = component.connect
    }
    
    func preprocess(request: Request, context: Context) throws {
        return try preprocess(request, context)
    }
    
    func postprocess(response: Response, for request: Request, context: Context) throws {
        return try postprocess(response, request, context)
    }
    
    func recover(error: Error, for request: Request, context: Context) throws -> Response {
        return try recover(error, request, context)
    }
    
    func get(request: Request, context: Context) throws -> Response {
        return try get(request, context)
    }
    
    func post(request: Request, context: Context) throws -> Response {
        return try post(request, context)
    }
    
    func put(request: Request, context: Context) throws -> Response {
        return try put(request, context)
    }
    
    func patch(request: Request, context: Context) throws -> Response {
        return try patch(request, context)
    }
    
    func delete(request: Request, context: Context) throws -> Response {
        return try delete(request, context)
    }
    
    func head(request: Request, context: Context) throws -> Response {
        return try head(request, context)
    }
    
    func options(request: Request, context: Context) throws -> Response {
        return try options(request, context)
    }
    
    func trace(request: Request, context: Context) throws -> Response {
        return try trace(request, context)
    }
    
    func connect(request: Request, context: Context) throws -> Response {
        return try connect(request, context)
    }
}

extension AnyRouteComponent {
    func child(for pathComponent: String) throws -> (RouteComponentKey, AnyRouteComponent<Context>)? {
        if let (key, child) = pathComponentStrategyChildren[pathComponent] {
            return (key, child)
        }
        
        guard let (type, key, child) = parameterStrategyChild else {
            throw RouterError.notFound
        }
        
        guard type.init(pathComponent) != nil else {
            throw RouterError.invalidParameter
        }
        
        return (key, child)
    }
    
    func responder(for request: Request) throws -> (Request, Context) throws -> Response {
        switch request.method {
        case .get: return get
        case .post: return post
        case .put: return put
        case .patch: return patch
        case .delete: return delete
        case .head: return head
        case .options: return options
        case .trace: return trace
        case .connect: return connect
        default: throw RouterError.methodNotAllowed
        }
    }
}

