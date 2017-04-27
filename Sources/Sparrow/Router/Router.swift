import HTTP
import Core

/// With `Router` you can incrementally structure your API
///
/// Complex routes are built incrementally, adding subrouters to routers as you build your API
///
/// The default router, created with `Router()` is created with the base path of `"/"`.
/// To this base router, you can add subrouters using resources, or simply with closures if you like.
///
///     extension PathParameter {
///         static let name = PathParameter(rawValue: "name")
///     }
///
///     let router = Router()
///
///     // /greeting
///     router.add(pathLiteral: "greeting") { router in
///
///         // /greeting/:name
///         router.add(.name) { router in
///             router.get { request in
///                 return try Response(
///                     status: .ok,
///                     message: "Hello " + request.pathParameters.value(for: "name")
///                 )
///             }
///         }
///     }
///
///     // GET /
///     router.get { request in
///
///         return Response(
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

    fileprivate var requestPreprocessors: [(HTTPRequest.Method, RequestPreprocessor)] = []

    fileprivate var responsePreprocessors: [(HTTPRequest.Method, ResponsePreprocessor)] = []

    fileprivate var requestResponders: [HTTPRequest.Method: RequestResponder] = [:]

    /// Logger used by the router
    public let logger: Logger

    lazy public var recovery: ((Error) -> Response) = { _ in
        return Response(status: .internalServerError, message: "An unexpected error occurred")
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

    fileprivate func responsePreprocessors(for method: HTTPRequest.Method) -> [ResponsePreprocessor] {
        return responsePreprocessors.filter { $0.0 == method }.map { $0.1 }
    }

    fileprivate func requestPreprocessors(for method: HTTPRequest.Method) -> [RequestPreprocessor] {
        return requestPreprocessors.filter { $0.0 == method }.map { $0.1 }
    }
}

extension Router {

    /// Creates a `DELETE` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func delete(handler: @escaping (Request) throws -> Response) {
        respond(to: .delete, handler: handler)
    }

    /// Creates a `GET` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func get(handler: @escaping (Request) throws -> Response) {
        respond(to: .get, handler: handler)
    }

    /// Creates a `HEAD` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func head(handler: @escaping (Request) throws -> Response) {
        respond(to: .head, handler: handler)
    }

    /// Creates a `POST` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func post(handler: @escaping (Request) throws -> Response) {
        respond(to: .post, handler: handler)
    }

    /// Creates a `PUT` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func put(handler: @escaping (Request) throws -> Response) {
        respond(to: .put, handler: handler)
    }

    /// Creates a `CONNECT` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func connect(handler: @escaping (Request) throws -> Response) {
        respond(to: .connect, handler: handler)
    }

    /// Creates a `OPTIONS` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func options(handler: @escaping (Request) throws -> Response) {
        respond(to: .options, handler: handler)
    }

    /// Creates a `TRACE` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func trace(handler: @escaping (Request) throws -> Response) {
        respond(to: .trace, handler: handler)
    }

    /// Creates a `PATCH` responder for this router
    ///
    /// - Parameter handler: Handler closure invoked when the method is called
    public func patch(handler: @escaping (Request) throws -> Response) {
        respond(to: .patch, handler: handler)
    }
}

extension Router {
    @discardableResult
    fileprivate func add<T: Route>(_ route: T, to component: PathComponent) -> Router {

        return add(component: component) { router in
            router.delete(handler: route.delete(request:))
            router.get(handler: route.get(request:))
            router.head(handler: route.head(request:))
            router.post(handler: route.post(request:))
            router.put(handler: route.put(request:))
            router.connect(handler: route.connect(request:))
            router.options(handler: route.options(request:))
            router.trace(handler: route.trace(request:))
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

    public func respond(to methods: [HTTPRequest.Method], using handler: RequestResponder) {
        for method  in methods {
            requestResponders[method] = handler
        }
    }

    public func respond(to method: HTTPRequest.Method, using handler: RequestResponder) {
        respond(to: [method], using: handler)
    }

    /// Creates a responder for this router responding to the supplied methods
    ///
    /// - Parameters:
    ///   - methods: Methods to respond do
    ///   - handler: Handler closure invoked when the methods are called
    public func respond(to methods: [HTTPRequest.Method], handler: @escaping (Request) throws -> Response) {
        respond(to: methods, using: BasicRequestResponder(handler: handler))
    }

    /// Creates a responder for this router responding to the supplied method
    ///
    /// - Parameters:
    ///   - method: Methods to respond do
    ///   - handler: Handler closure invoked when the method is called
    public func respond(to method: HTTPRequest.Method, handler: @escaping (Request) throws -> Response) {
        respond(to: method, using: BasicRequestResponder(handler: handler))
    }
}

extension Router {

    /// Creates a request preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - methods: Methods triggering preprocessing
    ///   - handler: Handler closure invoked for the supplied methods
    public func processRequest(for methods: [HTTPRequest.Method], handler: @escaping (Request) throws -> Void) {
        for method in methods {
            requestPreprocessors.append((method, BasicRequestPreprocessor(handler: handler)))
        }
    }

    /// Creates a request preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - method: Method triggering preprocessing
    ///   - handler: Handler closure invoked for the supplied method
    public func processRequest(for method: HTTPRequest.Method, handler: @escaping (Request) throws -> Void) {
        processRequest(for: [method], handler: handler)
    }

    /// Adds a request preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - methods: Methods triggering preprocessing
    func add(processor: RequestPreprocessor, for methods: [HTTPRequest.Method]) {
        processRequest(for: methods, handler: processor.process)
    }

    /// Adds a request preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - method: Method triggering preprocessing
    func add(processor: RequestPreprocessor, for method: HTTPRequest.Method) {
        processRequest(for: method, handler: processor.process)
    }
}

extension Router {

    /// Creates a response preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - methods: Methods triggering preprocessing
    ///   - handler: Handler closure invoked invoked for the supplied methods
    public func processResponse(for methods: [HTTPRequest.Method], handler: @escaping (Response) throws -> Void) {
        for method in methods {
            responsePreprocessors.append((method, BasicResponsePreprocessor(handler: handler)))
        }
    }

    /// Creates a response preprocessor for the supplied method to this router
    ///
    /// - Parameters:
    ///   - method: Method triggering preprocessing
    ///   - handler: Handler closure invoked invoked for the supplied methods
    public func processResponse(for method: HTTPRequest.Method, handler: @escaping (Response) throws -> Void) {
        processResponse(for: [method], handler: handler)
    }

    /// Adds a response preprocessor for the supplied methods to this route
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - methods: Methods triggering the preprocessor invocation
    func add(processor: ResponsePreprocessor, for methods: [HTTPRequest.Method]) {
        processResponse(for: methods, handler: processor.process)
    }

    /// Adds a response preprocessor for the supplied method to this route
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - method: Methods triggering the preprocessor invocation
    func add(processor: ResponsePreprocessor, for method: HTTPRequest.Method) {
        processResponse(for: method, handler: processor.process)
    }
}

extension Router {
    /// Adds a request and response preprocessor for the supplied methods to this router
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - methods: Methods triggering the request and response processor
    func add(processor: ContextPreprocessor, for methods: [HTTPRequest.Method]) {
        processRequest(for: methods, handler: processor.process)
        processResponse(for: methods, handler: processor.process)
    }

    /// Adds a request and response preprocessor for the supplied method to this router
    ///
    /// - Parameters:
    ///   - processor: Preprocessor invoked for supplied methods
    ///   - method: Method triggering the request and response processor
    func add(processor: ContextPreprocessor, for method: HTTPRequest.Method) {
        processRequest(for: method, handler: processor.process)
        processResponse(for: method, handler: processor.process)
    }
}

extension Router {

    fileprivate func matchingRouterChain(
        for pathComponents: [String],
        depth: Array<String>.Index = 0,
        request: Request,
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
                request: request,
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

extension Router: RequestResponder {

    public func respond(to request: Request) throws -> Response {
        do {

            let response: Response

            let urlPathComponents = request.httpRequest.url.pathComponents

            let routers: [Router]

            // Extract the body, and parse if, if needed
            if
                let contentLength = request.httpRequest.contentLength,
                contentLength > 0,
                let contentType = request.httpRequest.contentType {
                request.content = try contentNegotiator.parse(body: request.httpRequest.body, mediaType: contentType, deadline: .never)
            }

            routers = matchingRouterChain(for: urlPathComponents, request: request)

            // Validate chain of routers making sure that the chain isn't empty,
            // and that the last router has an action associated with the request's method
            guard
                !routers.isEmpty,
                let endpointRouter = routers.last
                else {
                    throw HTTPError(error: .notFound)
            }

            // Get the endpoint request responder
            guard let requestResponder = endpointRouter.requestResponders[request.httpRequest.method] else {

                // No responder found – if the responders are empty, an error with 404 status should be
                // thrown
                if endpointRouter.requestResponders.isEmpty {
                    throw HTTPError(error: .notFound)
                    // Other methods exist, but the supplied method isn't supported
                } else {

                    let validMethodsString = endpointRouter.requestResponders.keys.map({ $0.description }).joined(separator: ", ")

                    throw HTTPError(
                        error: .methodNotAllowed,
                        reason: "Unsupported method \(request.httpRequest.method.description). Supported methods: \(validMethodsString)"
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

            // Update request
            request.pathParameters = Parameters(contents: parametersByName)

            // Request request preprocessors
            for router in routers {
                for requestPreprocessor in router.requestPreprocessors(for: request.httpRequest.method) {
                    try requestPreprocessor.process(request: request)
                }
            }

            response = try requestResponder.respond(to: request)

            for router in routers {
                for responsePreprocessor in router.responsePreprocessors(for: request.httpRequest.method) {
                    try responsePreprocessor.process(response: response)
                }
            }

            return response

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

        } catch {
            throw error
        }
    }
}

extension Router: HTTPResponder {

    fileprivate func httpResponse(from response: Response, for mediaTypes: [MediaType]) throws -> HTTPResponse {

        // If the response has no content to serialize, return its response
        guard let content = response.content else {
            return response.httpResponse
        }

        // Serialize content, modify response and return it
        let (body, mediaType) = try contentNegotiator.serialize(content: content, mediaTypes: mediaTypes, deadline: .never)
        var headers = response.httpResponse.headers
        headers[HTTPHeader.contentType] = mediaType.description

        response.httpResponse.headers = headers
        response.httpResponse.body = body

        return response.httpResponse
    }

    public func respond(to httpRequest: HTTPRequest) throws -> HTTPResponse {

        // Create a request from the request
        let request = Request(request: httpRequest, logger: logger)

        logger.debug(httpRequest.description)

        let httpResponse: HTTPResponse

        process: do {
            // Process the request, creating a response
            let response = try self.respond(to: request)

            httpResponse = try self.httpResponse(from: response, for: request.httpRequest.accept)

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
                httpResponse = try self.httpResponse(
                    from: Response(status: error.status),
                    for: request.httpRequest.accept
                )
                break process
            }

            // Content wrapping the error
            var content = Content()
            try content.set(value: errorContent, forKey: "error")

            // Return a response with the error content
            httpResponse = try self.httpResponse(
                from: Response(status: error.status, content: content),
                for: request.httpRequest.accept
            )

            // Catch content negotiator unsupported media types error
        } catch ContentNegotiator.Error.unsupportedMediaTypes(let mediaTypes) {

            switch mediaTypes.count {
            case 0:
                return HTTPResponse(
                    status: .badRequest,
                    headers: [HTTPHeader.contentType: MediaType.plainText.description],
                    body: "Accept header missing, or does not supply accepted media types"
                )
            case 1:
                return HTTPResponse(
                    status: .badRequest,
                    headers: [HTTPHeader.contentType: MediaType.plainText.description],
                    body: "Media type \"\(mediaTypes[0])\" is unsupported"
                )
            default:
                let mediaTypesString = mediaTypes.map({ "\"\($0.description)\"" }).joined(separator: ", ")

                return HTTPResponse(
                    status: .badRequest,
                    headers: [HTTPHeader.contentType: MediaType.plainText.description],
                    body: "None of the accepted media types (\(mediaTypesString)) are supported"
                )
            }
        } catch {
            // Run a recovery
            httpResponse = try self.httpResponse(from: recovery(error), for: request.httpRequest.accept)
        }

        logger.debug(httpResponse.description)
        return httpResponse
    }
}
