internal struct RouteChain {
    internal let method: HTTP.Request.Method
    internal let preprocessors: [Route.RequestPreprocessor]
    internal let action: Route.Action
    internal let pathSegments: [PathSegment]
    internal let pathParameters: PathParameters

    init?(method: Request.Method, routes: [Route], pathComponents: [String]) {

        guard !routes.isEmpty else {
            return nil
        }

        guard let action = routes.last?.actions[method] else {
            return nil
        }

        self.action = action

        self.method = method

        var preprocessors: [Route.RequestPreprocessor] = []

        for route in routes {
            if let routeHandler = route.preprocessors[method] {
                preprocessors.append(routeHandler)
            }
        }

        self.preprocessors = preprocessors
        pathSegments = routes.map {
            $0.pathSegment
        }

        var parametersByName: [String: String] = [:]

        for (pathSegment, pathComponent) in zip(pathSegments, pathComponents) {
            guard case .parameter(let name) = pathSegment else {
                continue
            }

            parametersByName[name] = pathComponent
        }

        self.pathParameters = PathParameters(contents: parametersByName)
    }
}

extension RouteChain: CustomDebugStringConvertible {
    internal var debugDescription: String {
        return pathSegments.map({ $0.debugDescription }).joined(separator: "/")
    }
}

extension RouteChain: Responder {

    public func respond(to request: Request) throws -> Response {

        var request = request

        for handler in preprocessors {
            switch try handler(request, pathParameters) {
            case .continue(let processedRequest):
                request = processedRequest
            case .break(let response):
                return response
            }
        }
        
        return try action(request, pathParameters)
    }
}
