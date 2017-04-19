internal struct RouteChain {
    internal let method: HTTP.Request.Method
    internal let handlers: [(Request) throws -> Route.RequestProcessResult]
    internal let action: Responder
    internal let pathSegments: [PathSegment]

    init?(method: Request.Method, routes: [Route]) {

        guard !routes.isEmpty else {
            return nil
        }

        guard let action = routes.last?.actions[method] else {
            return nil
        }

        self.action = action

        self.method = method

        var handlers: [(Request) throws -> Route.RequestProcessResult] = []

        for route in routes {
            if let routeHandler = route.handlers[method] {
                handlers.append(routeHandler)
            }
        }

        self.handlers = handlers
        pathSegments = routes.map {
            $0.pathSegment
        }
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

        for handler in handlers {
            switch try handler(request) {
            case .continue(let processedRequest):
                request = processedRequest
            case .break(let response):
                return response
            }
        }
        
        return try action.respond(to: request)
    }
}
