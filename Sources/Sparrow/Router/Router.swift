import HTTP
import Core

public class Router {

    internal enum PathSegment {
        case literal(String)
        case parameter(String)
    }

    fileprivate(set) public var children: [Router] = []

    /// Content negotiator of the router
    public let contentNegotiator: ContentNegotiator

    internal let pathSegment: PathSegment

    internal var requestPreprocessors: [(Request.Method, RequestContextPreprocessor)] = []

    internal var responsePreprocessors: [(Request.Method, ResponseContextPreprocessor)] = []

    internal var requestContextResponders: [Request.Method: RequestContextResponder] = [:]

    /// Logger used by the router
    public let logger: Logger

    lazy public var recovery: ((Error) -> ResponseContext) = { _ in
        return ResponseContext(status: .internalServerError, message: "An unexpected error occurred")
    }

    internal init(pathSegment: PathSegment, contentNegotiator: ContentNegotiator, logger: Logger) {
        self.pathSegment = pathSegment
        self.contentNegotiator = contentNegotiator
        self.logger = logger
    }

    /// Creates a new router with path component "/"
    ///
    /// - Parameters:
    ///   - contentNegotiator: Content negotiator
    ///   - logger: Logger
    public convenience init(contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(pathComponent: "/", contentNegotiator: contentNegotiator, logger: logger)
    }

    public convenience init(pathComponent: String, contentNegotiator: ContentNegotiator, logger: Logger =  Logger()) {
        self.init(pathSegment: .literal(pathComponent), contentNegotiator: contentNegotiator, logger: logger)
    }

    public convenience init(parameter parameterName: String, contentNegotiator: ContentNegotiator, logger: Logger =  Logger()) {
        self.init(pathSegment: .parameter(parameterName), contentNegotiator: contentNegotiator, logger: logger)
    }

    public func add(router: Router) {
        self.children.append(router)
    }

    public func add(routers: [Router]) {
        self.children += routers
    }

    internal func add(pathSegment: PathSegment, builder: (Router) -> Void) {
        let router = Router(pathSegment: pathSegment, contentNegotiator: contentNegotiator, logger: logger)
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

    public func get(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .get, handler: handler)
    }

    public func post(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .post, handler: handler)
    }

    public func put(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .put, handler: handler)
    }

    public func patch(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .patch, handler: handler)
    }

    public func delete(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .delete, handler: handler)
    }

}

extension Router {

    public func respond(to methods: [Request.Method], handler: @escaping (RequestContext) throws -> ResponseContext) {
        for method  in methods {
            requestContextResponders[method] = BasicRequestContextResponder(handler: handler)
        }
    }

    public func respond(to method: Request.Method, handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: [method], handler: handler)
    }
}

extension Router {

    public func processRequest(for methods: [Request.Method], handler: @escaping (RequestContext) throws -> RequestContextProcessingResult) {
        for method in methods {
            requestPreprocessors.append((method, BasicRequestContextPreprocessor(handler: handler)))
        }
    }

    public func processRequest(for method: Request.Method, handler: @escaping (RequestContext) throws -> RequestContextProcessingResult) {
        processRequest(for: [method], handler: handler)
    }

    func add(processor: RequestContextPreprocessor, for methods: [Request.Method]) {
        processRequest(for: methods, handler: processor.process)
    }

    func add(processor: RequestContextPreprocessor, for method: Request.Method) {
        processRequest(for: method, handler: processor.process)
    }
}

extension Router {

    public func processResponse(for methods: [Request.Method], handler: @escaping (ResponseContext) throws -> ResponseContext) {
        for method in methods {
            responsePreprocessors.append((method, BasicResponseContextPreprocessor(handler: handler)))
        }
    }

    public func processResponse(for method: Request.Method, handler: @escaping (ResponseContext) throws -> ResponseContext) {
        processResponse(for: [method], handler: handler)
    }

    func add(processor: ResponseContextPreprocessor, for methods: [Request.Method]) {
        processResponse(for: methods, handler: processor.process)
    }

    func add(processor: ResponseContextPreprocessor, for method: Request.Method) {
        processResponse(for: method, handler: processor.process)
    }
}

extension Router {
    func add(processor: ContextPreprocessor, for methods: [Request.Method]) {
        processRequest(for: methods, handler: processor.process)
        processResponse(for: methods, handler: processor.process)
    }

    func add(processor: ContextPreprocessor, for method: Request.Method) {
        processRequest(for: method, handler: processor.process)
        processResponse(for: method, handler: processor.process)
    }
}

extension Router {

    internal func response(from responseContext: ResponseContext, processors: [ResponseContextPreprocessor], for mediaTypes: [MediaType]) throws -> Response {

        var responseContext = responseContext

        for processor in processors {
            responseContext = try processor.process(responseContext: responseContext)
        }

        guard let content = responseContext.content else {
            return responseContext.response
        }

        let (body, mediaType) = try contentNegotiator.serialize(content: content, mediaTypes: mediaTypes, deadline: .never)
        var headers = responseContext.response.headers
        headers[Header.contentType] = mediaType.description

        responseContext.response.headers = headers
        responseContext.response.body = body

        return responseContext.response
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

        let context = RequestContext(request: request, logger: logger)

        let pathComponents = context.request.url.pathComponents

        do {

            // Extract the body, and parse if, if needed
            if
                let contentLength = context.request.contentLength,
                contentLength > 0,
                let contentType = context.request.contentType {
                context.content = try contentNegotiator.parse(body: context.request.body, mediaType: contentType, deadline: .never)
            }

            // Validate chain of routers making sure that the chain isn't empty,
            // and that the last router has an action associated with the request's method
            guard
                let routers = matchingRouterChain(for: pathComponents, context: context),
                !routers.isEmpty,
                let endpointRouter = routers.last
                else {
                    throw HTTPError(error: .notFound)
            }

            guard let requestContextResponder = endpointRouter.requestContextResponders[context.request.method] else {

                if endpointRouter.requestContextResponders.isEmpty {
                    throw HTTPError(error: .notFound)
                } else {
                    let validMethodsString = endpointRouter.requestContextResponders.keys.map({ $0.description }).joined(separator: ", ")
                    throw HTTPError(error: .methodNotAllowed, reason: "Unsupported method \(context.request.method.description). Supported methods: \(validMethodsString)")
                }
            }

            var requestProcessors: [RequestContextPreprocessor] = []
            var responseProcessors: [ResponseContextPreprocessor] = []

            // Extract all preprocessors
            for router in routers {

                requestProcessors += router.requestPreprocessors.filter { method, _ in
                    method == context.request.method
                }.map { $0.1 }

                responseProcessors += router.responsePreprocessors.filter { method, _ in
                    method == context.request.method
                    }.map { $0.1 }
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
            for requestProcessor in requestProcessors {
                switch try requestProcessor.process(requestContext: context) {

                case .continue:
                    break

                case .break(let breakingResponseContext):
                    return try response(from: breakingResponseContext, processors: responseProcessors, for: context.request.accept)
                }
            }

            return try response(from: requestContextResponder.respond(to: context), processors: responseProcessors, for: context.request.accept)

            // Catch thrown HTTP errors – they should be presented with the content negotiator
        } catch let error as HTTPError {

            var errorContent = Content()

            if let reason = error.reason {
                try errorContent.set(value: reason, forKey: "message")
            }

            if let code = error.code {
                try errorContent.set(value: code, forKey: "code")
            }

            guard !errorContent.isEmpty else {
                return Response(
                    status: error.status
                )
            }

            var content = Content()
            try content.set(value: errorContent, forKey: "error")

            let (body, mediaType) = try contentNegotiator.serialize(
                content: content,
                mediaTypes: context.request.accept,
                deadline: .never
            )

            var headers = error.headers
            headers[Header.contentType] = mediaType.description

            return Response(
                status: error.status,
                headers: headers,
                body: body
            )

            // Catch content negotiator unsupported media types error
        } catch ContentNegotiator.Error.unsupportedMediaTypes(let mediaTypes) {

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
            // Run a recovery
            return try response(from: recovery(error), processors: [], for: context.request.accept)
        }

    }
}
