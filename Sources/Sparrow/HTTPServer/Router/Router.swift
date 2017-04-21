import HTTP
import Core

public class Router {

    public typealias ResponseContextResponder = (RequestContext) throws -> ResponseContext
    public typealias RequestContextPreprocessor = (RequestContext) throws -> RequestContextProcessingResult

    public enum RequestContextProcessingResult {
        case `continue`
        case `break`(ResponseContext)
    }

    fileprivate(set) public var children: [Router] = []

    public let contentNegotiator: ContentNegotiator

    public let pathSegment: PathSegment

    internal var preprocessors: [Request.Method: RequestContextPreprocessor] = [:]

    internal var actions: [Request.Method: ResponseContextResponder] = [:]

    public lazy var fallback: ResponseContextResponder = { _ in
        return .response(Response(status: self.actions.isEmpty ? .notFound : .methodNotAllowed))
    }

    public var recovery: ((Error) -> ResponseContext)?

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

    internal func add(pathSegment: PathSegment, builder: (Router) -> Void) {
        let router = Router(pathSegment: pathSegment, contentNegotiator: contentNegotiator)
        builder(router)
        add(router: router)
    }

    public func add(pathComponent: String, builder: (Router) -> Void) {
        add(pathSegment: .literal(pathComponent), builder: builder)
    }

    public func add(parameter: String, builder: (Router) -> Void) {
        add(pathSegment: .parameter(parameter), builder: builder)
    }

    internal func add(pathSegment: PathSegment, resource: Resource) {
        add(pathSegment: pathSegment) { router in
            router.respond(to: .delete, handler: resource.delete(context:))
            router.respond(to: .get, handler: resource.get(context:))
            router.respond(to: .head, handler: resource.head(context:))
            router.respond(to: .post, handler: resource.post(context:))
            router.respond(to: .put, handler: resource.put(context:))
            router.respond(to: .options, handler: resource.options(context:))
            router.respond(to: .patch, handler: resource.patch(context:))
        }
    }

    public func add(pathComponent: String, resource: Resource) {
        add(pathSegment: .literal(pathComponent), resource: resource)
    }

    public func add(parameter: String, resource: Resource) {
        add(pathSegment: .parameter(parameter), resource: resource)
    }
}

extension Router {

    public func respond(to method: Request.Method, handler: @escaping ResponseContextResponder) {
        actions[method] = handler
    }

    public func preprocess(for methods: [Request.Method], handler: @escaping RequestContextPreprocessor) {
        for method in methods {
            preprocessors[method] = handler
        }
    }
}

extension Router {

    internal func response(from payload: ResponseContext, for mediaTypes: [MediaType]) throws -> Response {
        switch payload {
        case .response(let response):
            return response
        case .view(let status, let headers, let view):

            let (body, mediaType) = try contentNegotiator.serialize(view: view, mediaTypes: mediaTypes, deadline: .never)
            var headers = headers
            headers[Header.contentType] = mediaType.description
            return Response(
                status: status,
                headers: headers,
                body: body
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

        let pathComponents = context.request.url.pathComponents

        do {
            // Extract the body, and parse if, if needed
            if
                let contentLength = context.request.contentLength,
                contentLength > 0,
                let contentType = context.request.contentType {
                context.payload = try contentNegotiator.parse(body: context.request.body, mediaType: contentType, deadline: .never)
            }

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

                case .break(let breakingResponseContext):
                    return try response(from: breakingResponseContext, for: context.request.accept)
                }
            }

            return try response(from: action(context), for: context.request.accept)

            // Catch thrown HTTP errors – they should be presented with the content negotiator
        } catch let error as HTTPError {

            let (body, mediaType) = try contentNegotiator.serialize(error: error, mediaTypes: context.request.accept, deadline: .never)

            var headers = error.headers
            headers[Header.contentType] = mediaType.description

            return Response(
                status: error.status,
                headers: headers,
                body: body
            )

            // Catch content negotiator unsupported media types error
        } catch ContentNegotiatorError.unsupportedMediaTypes(let mediaTypes) {

            switch mediaTypes.count {
            case 0:
                return Response(
                    status: .badRequest,
                    body: "Accept header missing, or does not supply accepted media types"
                )
            case 1:
                return Response(
                    status: .badRequest,
                    body: "Media type \"\(mediaTypes[0])\" is unsupported"
                )
            default:
                let mediaTypesString = mediaTypes.map({ "\"\($0.description)\"" }).joined(separator: ", ")

                return Response(
                    status: .badRequest,
                    body: "None of the accepted media types (\(mediaTypesString)) are supported"
                )
            }
        } catch {
            // Run a recovery, if exists
            guard let recovery = recovery else {

                // Lastly, throw the error as it's undhandled
                throw error
            }

            return try response(from: recovery(error), for: context.request.accept)
        }

    }
}
