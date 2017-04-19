import HTTP

public class Router {

    public typealias Action = (RequestContext) throws -> Response
    public typealias RequestContextPreprocessor = (RequestContext) throws -> RequestContextProcessingResult

    public enum RequestContextProcessingResult {
        case `continue`
        case `break`(Response)
    }

    fileprivate(set) public var children: [Router] = []

    public let pathSegment: PathSegment

    internal var preprocessors: [Request.Method: RequestContextPreprocessor] = [:]

    internal var actions: [Request.Method: Action] = [:]

    public lazy var fallback: Responder = BasicResponder { _ in
        return Response(status: self.actions.isEmpty ? .notFound : .methodNotAllowed)
    }

    internal init(pathSegment: PathSegment) {
        self.pathSegment = pathSegment
    }

    public convenience init() {
        self.init(pathComponent: "/")
    }

    public convenience init(pathComponent: String) {
        self.init(pathSegment: .literal(pathComponent))
    }

    public convenience init(parameter parameterName: String) {
        self.init(pathSegment: .parameter(parameterName))
    }

    public func add(child route: Router) {
        self.children.append(route)
    }

    public func add(children routes: [Router]) {
        self.children += routes
    }

    public func add(pathComponent: String, builder: (Router) -> Void) {
        let route = Router(pathComponent: pathComponent)
        builder(route)
        add(child: route)
    }

    public func add(parameter: String, builder: (Router) -> Void) {
        let route = Router(parameter: parameter)
        builder(route)
        add(child: route)
    }
}

public extension Router {

    public func respond(to method: Request.Method, handler: @escaping Action) {
        actions[method] = handler
    }

    public func processRequest(for methods: [Request.Method], handler: @escaping RequestContextPreprocessor) {
        for method in methods {
            preprocessors[method] = handler
        }
    }
}

internal extension Router {

    internal func matchingRouteChain(for pathComponents: [String], depth: Array<String>.Index = 0, request: HTTP.Request, parents: [Router] = []) -> RouterChain? {

        guard pathComponents.count > depth else {
            return nil
        }

        if case .literal(let string) = pathSegment {
            guard string == pathComponents[depth] else {
                return nil
            }
        }

        guard depth != pathComponents.index(before: pathComponents.endIndex) else {
            return RouterChain(request: request, routes: parents + [self], pathComponents: pathComponents)
        }

        for child in children {
            guard let matching = child.matchingRouteChain(for: pathComponents, depth: depth.advanced(by: 1), request: request, parents: parents + [self]) else {
                continue
            }
            return matching
        }

        return nil
    }
}

extension Router: Responder {
    public func respond(to request: Request) throws -> Response {

        let pathComponents = request.url.pathComponents

        guard let routeChain = matchingRouteChain(for: pathComponents, request: request) else {
            return try fallback.respond(to: request)
        }

        return try routeChain.respond(to: request)

    }
}
