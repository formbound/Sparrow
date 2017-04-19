import HTTP

public class Route {

    public typealias Action = (Request, PathParameters) throws -> Response
    public typealias RequestPreprocessor = (Request, PathParameters) throws -> RequestProcessResult

    public enum RequestProcessResult {
        case `continue`(Request)
        case `break`(Response)
    }

    fileprivate(set) public var children: [Route] = []
    public let pathSegment: PathSegment
    internal var preprocessors: [Request.Method: RequestPreprocessor] = [:]
    internal var actions: [Request.Method: Action] = [:]

    internal init(pathSegment: PathSegment) {
        self.pathSegment = pathSegment
    }

    public init(pathComponent: String) {
        self.pathSegment = .literal(pathComponent)
    }

    public init(parameter parameterName: String) {
        self.pathSegment = .parameter(parameterName)
    }

    public func add(child route: Route) {
        self.children.append(route)
    }

    public func add(children routes: [Route]) {
        self.children += routes
    }

    public func add(pathComponent: String, builder: (Route) -> Void) {
        let route = Route(pathComponent: pathComponent)
        builder(route)
        add(child: route)
    }

    public func add(parameter: String, builder: (Route) -> Void) {
        let route = Route(parameter: parameter)
        builder(route)
        add(child: route)
    }
}

public extension Route {

    public func respond(to method: Request.Method, handler: @escaping Action) {
        actions[method] = handler
    }

    public func processRequest(for methods: [Request.Method], handler: @escaping RequestPreprocessor) {
        for method in methods {
            preprocessors[method] = handler
        }
    }
}

internal extension Route {

    internal func matchingRouteChain(for pathComponents: [String], depth: Array<String>.Index = 0, method: HTTP.Request.Method, parents: [Route] = []) -> RouteChain? {


        guard pathComponents.count > depth else {
            return nil
        }

        if case .literal(let string) = pathSegment {
            guard string == pathComponents[depth] else {
                return nil
            }
        }

        guard depth != pathComponents.index(before: pathComponents.endIndex) else {
            return RouteChain(method: method, routes: parents + [self], pathComponents: pathComponents)
        }

        for child in children {
            guard let matching = child.matchingRouteChain(for: pathComponents, depth: depth.advanced(by: 1), method: method, parents: parents + [self]) else {
                continue
            }
            return matching
        }

        return nil
    }
}



