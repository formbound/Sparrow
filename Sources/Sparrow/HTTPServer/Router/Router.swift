import HTTP
import Core

public enum Payload {
    case view(Response.Status, Headers, View)
    case response(Response)

    public init(response: Response) {
        self = .response(response)
    }

    public init(status: Response.Status, headers: Headers = [:], view: View) {
        self = .view(status, headers, view)
    }

    public init(status: Response.Status, headers: Headers = [:], message: String) {
        self.init(status: status, headers: headers, view: ["message": message])
    }

    public init(status: Response.Status, headers: Headers = [:], view: ViewRepresentable) {
        self.init(status: status, headers: headers, view: view.view)
    }
}

public class Router {

    public typealias PayloadResponder = (RequestContext) throws -> Payload
    public typealias RequestContextPreprocessor = (RequestContext) throws -> RequestContextProcessingResult

    public enum RequestContextProcessingResult {
        case `continue`
        case `break`(Payload)
    }

    fileprivate(set) public var children: [Router] = []

    public let contentNegotiator: ContentNegotiator

    public let pathSegment: PathSegment

    internal var preprocessors: [Request.Method: RequestContextPreprocessor] = [:]

    internal var actions: [Request.Method: PayloadResponder] = [:]

    public lazy var fallback: PayloadResponder = { _ in
        return .response(Response(status: self.actions.isEmpty ? .notFound : .methodNotAllowed))
    }

    public var recovery: ((Error) -> Payload)?

    internal init(pathSegment: PathSegment, contentNegotiator: ContentNegotiator) {
        self.pathSegment = pathSegment
        self.contentNegotiator = contentNegotiator
    }

    public convenience init(contentNegotiator: ContentNegotiator = StandardContentNegotiator()) {
        self.init(pathComponent: "/", contentNegotiator: contentNegotiator)
    }

    public convenience init(pathComponent: String, contentNegotiator: ContentNegotiator) {
        self.init(pathSegment: .literal(pathComponent), contentNegotiator: contentNegotiator)
    }

    public convenience init(parameter parameterName: String, contentNegotiator: ContentNegotiator) {
        self.init(pathSegment: .parameter(parameterName), contentNegotiator: contentNegotiator)
    }

    public func add(router: Router) {
        self.children.append(router)
    }

    public func add(routers: [Router]) {
        self.children += routers
    }

    public func add(pathComponent: String, resource: Resource) {
        resource.add(to: self, pathComponent: pathComponent)
    }

    public func add(pathComponent: String, builder: (Router) -> Void) {
        let router = Router(pathComponent: pathComponent, contentNegotiator: contentNegotiator)
        builder(router)
        add(router: router)
    }

    public func add(parameter: String, builder: (Router) -> Void) {
        let router = Router(parameter: parameter, contentNegotiator: contentNegotiator)
        builder(router)
        add(router: router)
    }
}

extension Router {

    public func respond(to method: Request.Method, handler: @escaping PayloadResponder) {
        actions[method] = handler
    }

    public func preprocess(for methods: [Request.Method], handler: @escaping RequestContextPreprocessor) {
        for method in methods {
            preprocessors[method] = handler
        }
    }
}

extension Router {

    internal func response(from payload: Payload, for mediaTypes: [MediaType]) throws -> Response {
        switch payload {
        case .response(let response):
            return response
        case .view(let status, let headers, let view):
            return Response(
                status: status,
                headers: headers,
                body: try contentNegotiator.serialize(view: view, mediaTypes: mediaTypes, deadline: .never)
            )
        }
    }

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

extension Router: Responder {
    public func respond(to request: Request) throws -> Response {

        let context = RequestContext(request: request)

        if
            let contentLength = context.request.contentLength,
            contentLength > 0,
            let contentType = context.request.contentType {
            context.payload = try contentNegotiator.parse(body: context.request.body, mediaType: contentType, deadline: .never)
        }

        let pathComponents = context.request.url.pathComponents

        do {

            // Validate chain of routers making sure that the chain isn't empty,
            // and that the last router has an action associated with the request's method
            guard
                let routers = matchingRouterChain(for: pathComponents, context: context),
                !routers.isEmpty,
                let action = routers.last?.actions[context.request.method]
                else {
                    return try response(from: try fallback(context), for: context.request.accept)
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
            context.pathParameters = Parameters(contents: parametersByName)

            // Execute all preprocessors in order
            for handler in preprocessors {
                switch try handler(context) {

                case .continue:
                    break

                case .break(let breakingPayload):
                    return try response(from: breakingPayload, for: context.request.accept)
                }
            }

            do {
                return try response(from: action(context), for: context.request.accept)

            } catch {
                if let httpError = error as? HTTPError {
                    return Response(
                        status: httpError.status,
                        headers: httpError.headers,
                        body: try contentNegotiator.serialize(error: httpError, mediaTypes: context.request.accept, deadline: .never)
                    )
                } else {
                    throw error
                }
            }

        } catch {
            guard let recovery = recovery else {
                throw error
            }

            return try response(from: recovery(error), for: context.request.accept)
        }
    }
}
