import HTTP
import Core

public struct Present {
    let status: Response.Status
    let headers: Headers
    let view: View

    init(status: Response.Status = .ok, headers: Headers = [:], view: View) {
        self.status = status
        self.headers = headers
        self.view = view
    }
}

public class Router {

    public typealias ViewAction = (RequestContext) throws -> Present
    public typealias ResponseAction = (RequestContext) throws -> Response
    public typealias RequestContextPreprocessor = (RequestContext) throws -> RequestContextProcessingResult

    public enum RequestContextProcessingResult {
        case `continue`
        case `break`(Response)
    }

    public enum Action {
        case view((RequestContext) throws -> Present)
        case response((RequestContext) throws -> Response)
    }

    fileprivate(set) public var children: [Router] = []

    public let pathSegment: PathSegment

    internal var preprocessors: [Request.Method: RequestContextPreprocessor] = [:]

    internal var actions: [Request.Method: Action] = [:]

    public lazy var fallback: Responder = BasicResponder { _ in
        return Response(status: self.actions.isEmpty ? .notFound : .methodNotAllowed)
    }

    public var recovery: ((Error) -> Response)?

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

    internal func respond(to method: Request.Method, handler: Action) {
        actions[method] = handler
    }

    internal func respond(to method: Request.Method, handler: @escaping ViewAction) {
        actions[method] = .view(handler)
    }

    internal func respond(to method: Request.Method, handler: @escaping ResponseAction) {
        actions[method] = .response(handler)
    }

    public func preprocess(for methods: [Request.Method], handler: @escaping RequestContextPreprocessor) {
        for method in methods {
            preprocessors[method] = handler
        }
    }
}

internal extension Router {

    internal func matchingRouteChain(
        for pathComponents: [String],
        depth: Array<String>.Index = 0,
        request: HTTP.Request,
        parents: [Router] = []
    ) -> RouterChain? {

        guard pathComponents.count > depth else {
            return nil
        }

        if case .literal(let string) = pathSegment {
            guard string == pathComponents[depth] else {
                return nil
            }
        }

        guard depth != pathComponents.index(before: pathComponents.endIndex) else {
            return RouterChain(
                request: request,
                routes: parents + [self],
                pathComponents: pathComponents
            )
        }

        for child in children {
            guard let matching = child.matchingRouteChain(
                for: pathComponents,
                depth: depth.advanced(by: 1),
                request: request,
                parents: parents + [self]
            ) else {
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

        do {
            guard let routeChain = matchingRouteChain(for: pathComponents, request: request) else {
                return try fallback.respond(to: request)
            }


            for handler in routeChain.preprocessors {
                switch try handler(routeChain.requestContext) {

                case .continue:
                    break

                case .break(let response):
                    return response
                }
            }

            switch routeChain.action {

            case .view(let handler):
                let viewResponse = try handler(routeChain.requestContext)
                fatalError()
                
            case .response(let handler):
                return try handler(routeChain.requestContext)
            }

        } catch {
            guard let recovery = recovery else {
                throw error
            }

            return recovery(error)
        }

    }
}
