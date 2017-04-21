import HTTP
import Core

public enum Present {
    case view(Response.Status, Headers, View)
    case response(Response)

    init(response: Response) {
        self = .response(response)
    }

    init(status: Response.Status, headers: Headers = [:], view: View) {
        self = .view(status, headers, view)
    }

    init(status: Response.Status, headers: Headers = [:], view: ViewRepresentable) {
        self.init(status: status, headers: headers, view: view.view)
    }
}

public protocol RouterResponseRepresentable {
    var routerResponse: Present { get }
}

extension Response: RouterResponseRepresentable {
    public var routerResponse: Present {
        return Present(response: self)
    }
}

public class Router {

    public typealias RepresentableResponder = (RequestContext) throws -> RouterResponseRepresentable
    public typealias Responder = (RequestContext) throws -> Present
    public typealias RequestContextPreprocessor = (RequestContext) throws -> RequestContextProcessingResult

    public enum RequestContextProcessingResult {
        case `continue`
        case `break`(Present)
    }

    fileprivate(set) public var children: [Router] = []

    public let pathSegment: PathSegment

    internal var preprocessors: [Request.Method: RequestContextPreprocessor] = [:]

    internal var actions: [Request.Method: Responder] = [:]

    public lazy var fallback: Responder = { _ in
        return .response(Response(status: self.actions.isEmpty ? .notFound : .methodNotAllowed))
    }

    public var recovery: ((Error) -> Present)?

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

    public func respond(to method: Request.Method, handler: @escaping Responder) {
        actions[method] = handler
    }

    public func respond(to method: Request.Method, handler: @escaping RepresentableResponder) {
        actions[method] = { context in
            try handler(context).routerResponse
        }
    }

    public func preprocess(for methods: [Request.Method], handler: @escaping RequestContextPreprocessor) {
        for method in methods {
            preprocessors[method] = handler
        }
    }
}

internal extension Router {

    internal func matchingRouterChain(
        for pathComponents: [String],
        depth: Array<String>.Index = 0,
        context: RequestContext,
        parents: [Router] = []
    ) -> [Router]? {

        guard pathComponents.count > depth else {
            return nil
        }

        if case .literal(let string) = pathSegment {
            guard string == pathComponents[depth] else {
                return nil
            }
        }

        guard depth != pathComponents.index(before: pathComponents.endIndex) else {
            return parents + [self]
        }

        for child in children {
            guard let matching = child.matchingRouterChain(
                for: pathComponents,
                depth: depth.advanced(by: 1),
                context: context,
                parents: parents + [self]
            ) else {
                continue
            }
            return matching
        }

        return nil
    }
}

extension Router {
    public func respond(to context: RequestContext) throws -> Present {

        let pathComponents = context.request.url.pathComponents

        do {

            // Validate chain of routers making sure that the chain isn't empty,
            // and that the last router has an action associated with the request's method
            guard
                let routers = matchingRouterChain(for: pathComponents, context: context),
                !routers.isEmpty,
                let action = routers.last?.actions[context.request.method]
                else {
                    return try fallback(context)
            }

            var preprocessors: [Router.RequestContextPreprocessor] = []

            // Extract all preprocessors
            for router in routers {
                if let routeHandler = router.preprocessors[context.request.method] {
                    preprocessors.append(routeHandler)
                }
            }

            // Extract path parameters from the router chain
            var parametersByName: [String: String] = [:]

            for (pathSegment, pathComponent) in zip(routers.map { $0.pathSegment }, pathComponents) {
                guard case .parameter(let name) = pathSegment else {
                    continue
                }

                parametersByName[name] = pathComponent
            }


            // Update context
            context.pathParameters = PathParameters(contents: parametersByName)
            

            // Execute all preprocessors in order
            for handler in preprocessors {
                switch try handler(context) {

                case .continue:
                    break

                case .break(let response):
                    return response
                }
            }

            return try action(context)

        } catch {
            guard let recovery = recovery else {
                throw error
            }

            return recovery(error)
        }
    }
}
