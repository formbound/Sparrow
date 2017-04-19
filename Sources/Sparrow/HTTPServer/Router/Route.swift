import HTTP

public class Route {

    public enum RequestProcessResult {
        case `continue`(Request)
        case `break`(Response)
    }

    fileprivate(set) public var children: [Route] = []
    public let pathSegment: PathSegment
    internal var handlers: [Request.Method: (Request) throws -> RequestProcessResult] = [:]
    internal var actions: [Request.Method: Responder] = [:]

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
}

public extension Route {

    public func respond(to method: Request.Method, handler: @escaping (Request) throws -> Response) {
        actions[method] = BasicResponder { request in
            return try handler(request)
        }
    }

    public func processRequest(for method: Request.Method, handler: @escaping (Request) throws -> RequestProcessResult) {
        handlers[method] = handler
    }
}

internal extension Route {

    internal func matchingRouteChain(for pathComponents: [String], method: HTTP.Request.Method, parents: [Route] = []) -> RouteChain? {

        guard !pathComponents.isEmpty else {
            return nil
        }

        var pathComponents = pathComponents

        let firstPathComponent = pathComponents.removeFirst()

        if case .literal(let string) = pathSegment {
            guard string == firstPathComponent else {
                return nil
            }
        }

        guard !pathComponents.isEmpty else {
            return RouteChain(method: method, routes: parents + [self])
        }

        for child in children {
            guard let matching = child.matchingRouteChain(for: pathComponents, method: method, parents: parents + [self]) else {
                continue
            }
            return matching
        }

        return nil
    }
}



