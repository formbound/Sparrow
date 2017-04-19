import HTTP
import Foundation

public class Router {

    public var root: Route
    public var fallback: Responder

    init(routes: [Route] = []) {
        self.root = Route(pathComponent: "/")
        self.root.add(children: routes)
        self.fallback = BasicResponder { request in
            return Response(status: .methodNotAllowed)
        }
    }
}

extension Router: Responder {
    public func respond(to request: Request) throws -> Response {

        let pathComponents = request.url.pathComponents

        print(pathComponents)

        guard let routeChain = root.matchingRouteChain(for: pathComponents, method: request.method) else {
            return try fallback.respond(to: request)
        }

        return try routeChain.respond(to: request)


    }
}
