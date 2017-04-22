import HTTP
import Core

/// With `Router` you can incrementally structure your API
///
/// Complex routes are built incrementally, adding subrouters to routers as you build your API
///
/// The default router, created with `Router()` is created with the base path of `"/"`.
/// To this base router, you can add subrouters using resources, or simply with closures if you like.
///
///     let router = Router()
///
///     router.add(pathComponent: "greeting") { router in
///
///         router.add(parameterName: "name") { router in
///             router.get { context in
///                 return try ResponseContext(
///                     status: .ok,
///                     message: "Hello " + context.pathParameters.value(for: "name")
///                 )
///             }
///         }
///     }
///
///     // GET /
///     router.get { context in
///
///         return ResponseContext(
///             status: .ok,
///             message: "Hello world!"
///         )
///     }
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
    ///   - contentNegotiator: Content negotiator for the router to create. Defaults to the standard content negotiator
    ///   - logger: Logger used by the router. Defaults to the stanard logger, printing to standard out
    public convenience init(contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(pathComponent: "/", contentNegotiator: contentNegotiator, logger: logger)
    }

    /// Creates a new router with specified path component
    ///
    /// - Parameters:
    ///   - contentNegotiator: Content negotiator for the router to create. Defaults to the standard content negotiator
    ///   - logger: Logger used by the router. Defaults to the stanard logger, printing to standard out
    public convenience init(pathComponent: String, contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(pathSegment: .literal(pathComponent), contentNegotiator: contentNegotiator, logger: logger)
    }

    /// Creates a new router with specified path parameter name
    ///
    /// - Parameters:
    ///   - contentNegotiator: Content negotiator for the router to create. Defaults to the standard content negotiator
    ///   - logger: Logger used by the router. Defaults to the stanard logger, printing to standard out
    public convenience init(parameterName: String, contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(pathSegment: .parameter(parameterName), contentNegotiator: contentNegotiator, logger: logger)
    }

    /// Adds a router as a subrouter of this router
    ///
    /// - Parameter router: Router to add
    public func add(router: Router) {
        self.children.append(router)
    }

    /// Adds multible routers as a subrouters of this router
    ///
    /// - Parameter routers: Routers to add
    public func add(routers: [Router]) {
        self.children += routers
    }

    internal func add(pathSegment: PathSegment, builder: (Router) -> Void) {
        let router = Router(pathSegment: pathSegment, contentNegotiator: contentNegotiator, logger: logger)
        builder(router)
        add(router: router)
    }

    /// Creates and adds a new subrouter of this router, with a path component, using a construction handler
    ///
    /// - Note: The subrouter will inherit the parent's content negotiator and logger by default
    ///
    /// - Parameters:
    ///   - pathComponent: Path component of the subrouter
    ///   - builder: Handler used to configure the subrouter
    public func add(pathComponent: String, builder: (Router) -> Void) {
        add(pathSegment: .literal(pathComponent), builder: builder)
    }

    /// Creates and adds a new subrouter of this router, with a path parameter, using a construction handler
    ///
    /// - Note: The subrouter will inherit the parent's content negotiator and logger by default
    ///
    /// - Parameters:
    ///   - parameterName: Parameter name of the subrouter
    ///   - builder: Handler used to configure the subrouter
    public func add(parameterName: String, builder: (Router) -> Void) {
        add(pathSegment: .parameter(parameterName), builder: builder)
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

    /// Adds a resource, with a path component, as a subrouter to this router
    ///
    /// - Note: The subrouter created using the resource will inherit the parent's content negotiator and
    ///         logger by default
    ///
    /// - Parameters:
    ///   - pathComponent: Path component of the subrouter
    ///   - resource: Resource which supplies endpoints for the subrouter
    public func add(pathComponent: String, resource: Resource) {
        add(pathSegment: .literal(pathComponent), resource: resource)
    }

    /// Adds a resource, with a path parameter, as a subrouter to this router
    ///
    /// - Note: The subrouter created using the resource will inherit the parent's content negotiator and
    ///         logger by default
    ///
    /// - Parameters:
    ///   - pathComponent: Path component of the subrouter
    ///   - resource: Resource which supplies endpoints for the subrouter
    public func add(parameterName: String, resource: Resource) {
        add(pathSegment: .parameter(parameterName), resource: resource)
    }
}

extension Router {

    /// Creates a `GET` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func get(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .get, handler: handler)
    }

    /// Creates a `POST` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func post(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .post, handler: handler)
    }

    /// Creates a `PUT` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func put(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .put, handler: handler)
    }

    /// Creates a `PATCH` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func patch(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .patch, handler: handler)
    }

    /// Creates a `DELETE` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func delete(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .delete, handler: handler)
    }

}

extension Router {

    /// Creates a responder for this router responding to the supplied methods
    ///
    /// - Parameters:
    ///   - methods: Methods to respond do
    ///   - handler: Handler closure invoked when the methods are called
    public func respond(to methods: [Request.Method], handler: @escaping (RequestContext) throws -> ResponseContext) {
        for method  in methods {
            requestContextResponders[method] = BasicRequestContextResponder(handler: handler)
        }
    }

    /// Creates a responder for this router responding to the supplied method
    ///
    /// - Parameters:
    ///   - method: Methods to respond do
    ///   - handler: Handler closure invoked when the method is called
    public func respond(to method: Request.Method, handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: [method], handler: handler)
    }
}

extension Router {

    /// Creates a request preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - methods: Methods triggering preprocessing
    ///   - handler: Handler closure invoked for the supplied methods
    public func processRequest(for methods: [Request.Method], handler: @escaping (RequestContext) throws -> RequestContextProcessingResult) {
        for method in methods {
            requestPreprocessors.append((method, BasicRequestContextPreprocessor(handler: handler)))
        }
    }

    /// Creates a request preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - method: Method triggering preprocessing
    ///   - handler: Handler closure invoked for the supplied method
    public func processRequest(for method: Request.Method, handler: @escaping (RequestContext) throws -> RequestContextProcessingResult) {
        processRequest(for: [method], handler: handler)
    }

    /// Adds a request preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - methods: Methods triggering preprocessing
    func add(processor: RequestContextPreprocessor, for methods: [Request.Method]) {
        processRequest(for: methods, handler: processor.process)
    }

    /// Adds a request preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - method: Method triggering preprocessing
    func add(processor: RequestContextPreprocessor, for method: Request.Method) {
        processRequest(for: method, handler: processor.process)
    }
}

extension Router {

    /// Creates a response preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - methods: Methods triggering preprocessing
    ///   - handler: Handler closure invoked invoked for the supplied methods
    public func processResponse(for methods: [Request.Method], handler: @escaping (ResponseContext) throws -> ResponseContext) {
        for method in methods {
            responsePreprocessors.append((method, BasicResponseContextPreprocessor(handler: handler)))
        }
    }

    /// Creates a response preprocessor for the supplied method to this router
    ///
    /// - Parameters:
    ///   - method: Method triggering preprocessing
    ///   - handler: Handler closure invoked invoked for the supplied methods
    public func processResponse(for method: Request.Method, handler: @escaping (ResponseContext) throws -> ResponseContext) {
        processResponse(for: [method], handler: handler)
    }

    /// Adds a response preprocessor for the supplied methods to this route
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - methods: Methods triggering the preprocessor invocation
    func add(processor: ResponseContextPreprocessor, for methods: [Request.Method]) {
        processResponse(for: methods, handler: processor.process)
    }

    /// Adds a response preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - method: Methods triggering the preprocessor invocation
    func add(processor: ResponseContextPreprocessor, for method: Request.Method) {
        processResponse(for: method, handler: processor.process)
    }
}

extension Router {
    /// Adds a request and response preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - methods: Methods triggering the request and response processor
    func add(processor: ContextPreprocessor, for methods: [Request.Method]) {
        processRequest(for: methods, handler: processor.process)
        processResponse(for: methods, handler: processor.process)
    }

    /// Adds a request and response preprocessor for the supplied method to this router
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - method: Method triggering the request and response processor
    func add(processor: ContextPreprocessor, for method: Request.Method) {
        processRequest(for: method, handler: processor.process)
        processResponse(for: method, handler: processor.process)
    }
}

extension Router {

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

extension Router: RequestContextResponder {
    public func respond(to requestContext: RequestContext) throws -> ResponseContext {

        var responseContext: ResponseContext

        let pathComponents = requestContext.request.url.pathComponents

        var responseProcessors: [ResponseContextPreprocessor] = []

        do {

            // Extract the body, and parse if, if needed
            if
                let contentLength = requestContext.request.contentLength,
                contentLength > 0,
                let contentType = requestContext.request.contentType {
                requestContext.content = try contentNegotiator.parse(body: requestContext.request.body, mediaType: contentType, deadline: .never)
            }

            // Validate chain of routers making sure that the chain isn't empty,
            // and that the last router has an action associated with the request's method
            guard
                let routers = matchingRouterChain(for: pathComponents, context: requestContext),
                !routers.isEmpty,
                let endpointRouter = routers.last
                else {
                    throw HTTPError(error: .notFound)
            }

            guard let requestContextResponder = endpointRouter.requestContextResponders[requestContext.request.method] else {

                if endpointRouter.requestContextResponders.isEmpty {
                    throw HTTPError(error: .notFound)
                } else {
                    let validMethodsString = endpointRouter.requestContextResponders.keys.map({ $0.description }).joined(separator: ", ")
                    throw HTTPError(error: .methodNotAllowed, reason: "Unsupported method \(requestContext.request.method.description). Supported methods: \(validMethodsString)")
                }
            }

            var requestProcessors: [RequestContextPreprocessor] = []

            // Extract all preprocessors
            for router in routers {

                requestProcessors += router.requestPreprocessors.filter { method, _ in
                    method == requestContext.request.method
                    }.map { $0.1 }

                responseProcessors += router.responsePreprocessors.filter { method, _ in
                    method == requestContext.request.method
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
            requestContext.pathParameters = Parameters(contents: parametersByName)

            // Execute all preprocessors in order
            for requestProcessor in requestProcessors {
                switch try requestProcessor.process(requestContext: requestContext) {

                case .continue:
                    break

                case .break(let breakingResponseContext):
                    responseContext = breakingResponseContext
                }
            }

            responseContext = try requestContextResponder.respond(to: requestContext)

        } catch let error as ParametersError {

            let reason: String

            switch error {
            case .conversionFailed(let key):
                reason = "Illegal type of parameter \"\(key)\""
            case .missingValue(let key):
                reason = "Missing parameter for key \"\(key)\""
            }

            throw HTTPError(
                error: .badRequest,
                reason: reason
            )

            // Catch thrown HTTP errors – they should be presented with the content negotiator
        } catch {
            throw error
        }

        for responseProcessor in responseProcessors {
            responseContext = try responseProcessor.process(responseContext: responseContext)
        }

        return responseContext
    }
}

extension Router: Responder {

    internal func response(from responseContext: ResponseContext, for mediaTypes: [MediaType]) throws -> Response {

        // If the response context has no content to serialize, return its response
        guard let content = responseContext.content else {
            return responseContext.response
        }

        // Serialize content, modify response and return it
        let (body, mediaType) = try contentNegotiator.serialize(content: content, mediaTypes: mediaTypes, deadline: .never)
        var headers = responseContext.response.headers
        headers[Header.contentType] = mediaType.description

        responseContext.response.headers = headers
        responseContext.response.body = body

        return responseContext.response
    }

    public func respond(to request: Request) throws -> Response {

        let context = RequestContext(request: request, logger: logger)

        logger.debug(request.description)

        do {
            let responseContext = try respond(to: context)

            return try response(from: responseContext, for: context.request.accept)

        } catch let error as HTTPError {

            var errorContent = Content()

            if let reason = error.reason {
                try errorContent.set(value: reason, forKey: "message")
            }

            if let code = error.code {
                try errorContent.set(value: code, forKey: "code")
            }

            guard !errorContent.isEmpty else {
                return try response(
                    from: ResponseContext(status: error.status),
                    for: context.request.accept
                )
            }

            var content = Content()
            try content.set(value: errorContent, forKey: "error")

            return try response(
                from: ResponseContext(status: error.status, content: content),
                for: context.request.accept
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
            return try response(from: recovery(error), for: context.request.accept)
        }

    }
}
