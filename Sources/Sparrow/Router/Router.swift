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
///     // /greeting
///     router.add(pathLiteral: "greeting") { router in
///
///         // /greeting/:name
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
public final class Router {

    public enum PathComponent {
        case literal(String)
        case parameter(PathParameter)
    }

    fileprivate(set) public var children: [Router] = []

    /// Content negotiator of the router
    public let contentNegotiator: ContentNegotiator

    fileprivate let pathComponent: PathComponent

    fileprivate var requestContextPreprocessors: [(Request.Method, RequestContextPreprocessor)] = []

    fileprivate var responseContextPreprocessors: [(Request.Method, ResponseContextPreprocessor)] = []

    fileprivate var requestContextResponders: [Request.Method: RequestContextResponder] = [:]

    /// Logger used by the router
    public let logger: Logger

    lazy public var recovery: ((Error) -> ResponseContext) = { _ in
        return ResponseContext(status: .internalServerError, message: "An unexpected error occurred")
    }

    internal init(pathComponent: PathComponent, contentNegotiator: ContentNegotiator, logger: Logger) {
        self.pathComponent = pathComponent
        self.contentNegotiator = contentNegotiator
        self.logger = logger
    }

    /// Creates a new router with path component "/"
    ///
    /// - Parameters:
    ///   - contentNegotiator: Content negotiator for the router to create. Defaults to the standard content negotiator
    ///   - logger: Logger used by the router. Defaults to the stanard logger, printing to standard out
    public convenience init(contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(component: "/", contentNegotiator: contentNegotiator, logger: logger)
    }

    /// Creates a new router with specified path component
    ///
    /// - Parameters:
    ///   - contentNegotiator: Content negotiator for the router to create. Defaults to the standard content negotiator
    ///   - logger: Logger used by the router. Defaults to the stanard logger, printing to standard out
    public convenience init(component: String, contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(pathComponent: .literal(component), contentNegotiator: contentNegotiator, logger: logger)
    }

    /// Creates a new router with specified path parameter name
    ///
    /// - Parameters:
    ///   - contentNegotiator: Content negotiator for the router to create. Defaults to the standard content negotiator
    ///   - logger: Logger used by the router. Defaults to the stanard logger, printing to standard out
    public convenience init(parameter: PathParameter, contentNegotiator: ContentNegotiator = ContentNegotiator(), logger: Logger =  Logger()) {
        self.init(pathComponent: .parameter(parameter), contentNegotiator: contentNegotiator, logger: logger)
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

    fileprivate func add(component: PathComponent, builder: (Router) -> Void) -> Router {
        let router = Router(pathComponent: component, contentNegotiator: contentNegotiator, logger: logger)
        builder(router)
        add(router: router)
        return router
    }

    /// Creates and adds a new subrouter of this router, with a path component, using a construction handler
    ///
    /// - Note: The subrouter will inherit the parent's content negotiator and logger by default
    ///
    /// - Parameters:
    ///   - pathLiteral: Path component literal of the subrouter
    ///   - builder: Handler used to configure the subrouter
    @discardableResult
    public func add(_ literal: String, builder: (Router) -> Void) -> Router {
        return add(component: .literal(literal), builder: builder)
    }

    /// Creates and adds a new subrouter of this router, with a path parameter, using a construction handler
    ///
    /// - Note: The subrouter will inherit the parent's content negotiator and logger by default
    ///
    /// - Parameters:
    ///   - parameterName: Parameter name of the subrouter
    ///   - builder: Handler used to configure the subrouter
    @discardableResult
    public func add(_ parameter: PathParameter, builder: (Router) -> Void) -> Router {
        return add(component: .parameter(parameter), builder: builder)
    }
}

extension Router {

    fileprivate func responseContextPreprocessors(for method: Request.Method) -> [ResponseContextPreprocessor] {
        return responseContextPreprocessors.filter { $0.0 == method }.map { $0.1 }
    }

    fileprivate func requestContextPreprocessors(for method: Request.Method) -> [RequestContextPreprocessor] {
        return requestContextPreprocessors.filter { $0.0 == method }.map { $0.1 }
    }
}

extension Router {

    /// Creates a `DELETE` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func delete(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .delete, handler: handler)
    }

    /// Creates a `GET` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func get(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .get, handler: handler)
    }

    /// Creates a `HEAD` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func head(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .head, handler: handler)
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

    /// Creates a `CONNECT` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func connect(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .connect, handler: handler)
    }

    /// Creates a `OPTIONS` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func options(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .options, handler: handler)
    }

    /// Creates a `TRACE` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func trace(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .trace, handler: handler)
    }

    /// Creates a `PATCH` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func patch(handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: .patch, handler: handler)
    }
}

extension Router {
    @discardableResult
    fileprivate func add<T: Route>(_ route: T, to component: PathComponent) -> Router {

        return add(component: component) { router in
            router.delete(handler: route.delete(context:))
            router.get(handler: route.get(context:))
            router.head(handler: route.head(context:))
            router.post(handler: route.post(context:))
            router.put(handler: route.put(context:))
            router.connect(handler: route.connect(context:))
            router.options(handler: route.options(context:))
            router.trace(handler: route.trace(context:))
        }
    }

    @discardableResult
    internal func add<T: Route>(_ route: T, to component: String) -> Router {
        return add(route, to: .literal(component))
    }

    @discardableResult
    internal func add<T: Route>(_ route: T, to parameter: PathParameter) -> Router {
        return add(route, to: .parameter(parameter))
    }
}

extension Router {

    public func respond(to methods: [Request.Method], using handler: RequestContextResponder) {
        for method  in methods {
            requestContextResponders[method] = handler
        }
    }

    public func respond(to method: Request.Method, using handler: RequestContextResponder) {
        respond(to: [method], using: handler)
    }

    /// Creates a responder for this router responding to the supplied methods
    ///
    /// - Parameters:
    ///   - methods: Methods to respond do
    ///   - handler: Handler closure invoked when the methods are called
    public func respond(to methods: [Request.Method], handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: methods, using: BasicRequestContextResponder(handler: handler))
    }

    /// Creates a responder for this router responding to the supplied method
    ///
    /// - Parameters:
    ///   - method: Methods to respond do
    ///   - handler: Handler closure invoked when the method is called
    public func respond(to method: Request.Method, handler: @escaping (RequestContext) throws -> ResponseContext) {
        respond(to: method, using: BasicRequestContextResponder(handler: handler))
    }
}

extension Router {

    /// Creates a request preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - methods: Methods triggering preprocessing
    ///   - handler: Handler closure invoked for the supplied methods
    public func processRequest(for methods: [Request.Method], handler: @escaping (RequestContext) throws -> Void) {
        for method in methods {
            requestContextPreprocessors.append((method, BasicRequestContextPreprocessor(handler: handler)))
        }
    }

    /// Creates a request preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - method: Method triggering preprocessing
    ///   - handler: Handler closure invoked for the supplied method
    public func processRequest(for method: Request.Method, handler: @escaping (RequestContext) throws -> Void) {
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
    public func processResponse(for methods: [Request.Method], handler: @escaping (ResponseContext) throws -> Void) {
        for method in methods {
            responseContextPreprocessors.append((method, BasicResponseContextPreprocessor(handler: handler)))
        }
    }

    /// Creates a response preprocessor for the supplied method to this router
    ///
    /// - Parameters:
    ///   - method: Method triggering preprocessing
    ///   - handler: Handler closure invoked invoked for the supplied methods
    public func processResponse(for method: Request.Method, handler: @escaping (ResponseContext) throws -> Void) {
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

    fileprivate func matchingRouterChain(
        for pathComponents: [String],
        depth: Array<String>.Index = 0,
        context: RequestContext,
        parents: [Router] = []
        ) -> [Router] {

        guard pathComponents.count > depth else {
            return []
        }

        if case .literal(let string) = pathComponent {
            guard string == pathComponents[depth] else {
                return []
            }
        }

        guard depth != pathComponents.index(before: pathComponents.endIndex) else {
            return parents + [self]
        }

        for child in children {
            let matching = child.matchingRouterChain(
                for: pathComponents,
                depth: depth.advanced(by: 1),
                context: context,
                parents: parents + [self]
            )

            guard !matching.isEmpty else {
                continue
            }

            return matching
        }

        return []
    }
}

extension Router: RequestContextResponder {

    public func respond(to requestContext: RequestContext) throws -> ResponseContext {
        do {

            let responseContext: ResponseContext

            let urlPathComponents = requestContext.request.url.pathComponents

            let routers: [Router]

            // Extract the body, and parse if, if needed
            if
                let contentLength = requestContext.request.contentLength,
                contentLength > 0,
                let contentType = requestContext.request.contentType {
                requestContext.content = try contentNegotiator.parse(body: requestContext.request.body, mediaType: contentType, deadline: .never)
            }

            routers = matchingRouterChain(for: urlPathComponents, context: requestContext)

            // Validate chain of routers making sure that the chain isn't empty,
            // and that the last router has an action associated with the request's method
            guard
                !routers.isEmpty,
                let endpointRouter = routers.last
                else {
                    throw HTTPError(error: .notFound)
            }

            // Get the endpoint request context responder
            guard let requestContextResponder = endpointRouter.requestContextResponders[requestContext.request.method] else {

                // No responder found – if the responders are empty, an error with 404 status should be
                // thrown
                if endpointRouter.requestContextResponders.isEmpty {
                    throw HTTPError(error: .notFound)
                    // Other methods exist, but the supplied method isn't supported
                } else {

                    let validMethodsString = endpointRouter.requestContextResponders.keys.map({ $0.description }).joined(separator: ", ")

                    throw HTTPError(
                        error: .methodNotAllowed,
                        reason: "Unsupported method \(requestContext.request.method.description). Supported methods: \(validMethodsString)"
                    )
                }
            }

            // Extract path parameters from the router chain
            var parametersByName: [String: String] = [:]

            for (pathComponent, urlPathComponent) in zip(routers.map { $0.pathComponent }, urlPathComponents) {
                guard case .parameter(let name) = pathComponent else {
                    continue
                }

                parametersByName[name.rawValue] = urlPathComponent
            }

            // Update context
            requestContext.pathParameters = Parameters(contents: parametersByName)

            // Request context preprocessors
            for router in routers {
                for requestContextPreprocessor in router.requestContextPreprocessors(for: requestContext.request.method) {
                    try requestContextPreprocessor.process(requestContext: requestContext)
                }
            }

            responseContext = try requestContextResponder.respond(to: requestContext)

            for router in routers {
                for responseContextPreprocessor in router.responseContextPreprocessors(for: requestContext.request.method) {
                    try responseContextPreprocessor.process(responseContext: responseContext)
                }
            }

            return responseContext

            // Catch parameter errors, generating an HTTP error with status 400
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
    }
}

extension Router: Responder {

    fileprivate func response(from responseContext: ResponseContext, for mediaTypes: [MediaType]) throws -> Response {

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

        // Create a request context from the request
        let context = RequestContext(request: request, logger: logger)

        logger.debug(request.description)

        do {
            // Process the request context, creating a response context
            let responseContext = try self.responseContext(for: context)

            return try response(from: responseContext, for: context.request.accept)

            // Catch HTTP errors
        } catch let error as HTTPError {

            var errorContent = Content()

            // Add an error message to the response content, if exists
            if let reason = error.reason {
                try errorContent.set(value: reason, forKey: "message")
            }

            // Add an error code to the response content, if exists
            if let code = error.code {
                try errorContent.set(value: code, forKey: "code")
            }

            // If the error is empty, return a response without content
            guard !errorContent.isEmpty else {
                return try response(
                    from: ResponseContext(status: error.status),
                    for: context.request.accept
                )
            }

            // Content wrapping the error
            var content = Content()
            try content.set(value: errorContent, forKey: "error")

            // Return a response with the error content
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
                    headers: [Header.contentType: MediaType.plainText.description],
                    body: "Accept header missing, or does not supply accepted media types"
                )
            case 1:
                return Response(
                    status: .badRequest,
                    headers: [Header.contentType: MediaType.plainText.description],
                    body: "Media type \"\(mediaTypes[0])\" is unsupported"
                )
            default:
                let mediaTypesString = mediaTypes.map({ "\"\($0.description)\"" }).joined(separator: ", ")

                return Response(
                    status: .badRequest,
                    headers: [Header.contentType: MediaType.plainText.description],
                    body: "None of the accepted media types (\(mediaTypesString)) are supported"
                )
            }
        } catch {
            // Run a recovery
            return try response(from: recovery(error), for: context.request.accept)
        }
    }
}
