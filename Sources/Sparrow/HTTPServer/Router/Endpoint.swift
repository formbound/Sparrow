import HTTP

public struct Route: CustomDebugStringConvertible {

    public var children: [Route] = []
    public let pathSegment: PathSegment
    public var handlers: [Request.Method: (Request) throws -> Request] = [:]
    public var actions: [Request.Method: Responder] = [:]

    internal init(pathSegment: PathSegment) {
        self.pathSegment = pathSegment
    }

    public init(pathComponent: String) {
        self.pathSegment = .literal(pathComponent)
    }

    public init(parameter parameterName: String) {
        self.pathSegment = .parameter(parameterName)
    }
}

extension Route: Responder {

    public func respond(to request: Request) throws -> Response {

        guard let action = actions[request.method] else {
            throw HTTPError.notFound
        }

        return try action.respond(to: request)
    }

    public func willRespond(to method: HTTP.Request.Method) -> Bool {
        return actions[method] != nil
    }
}

public extension Route {

    public var debugDescription: String {

        switch pathSegment {
        case .literal(let literal):
            return literal
        case .parameter(let name):
            return "<\(name)>"
        }
    }

}

public extension Route {

    internal func matchingEndpoint(for pathComponents: [String], method: HTTP.Request.Method) -> [Route]? {

        guard !pathComponents.isEmpty else {
            return nil
        }

        var pathComponents = pathComponents

        var base: [Route] = []

        let firstPathComponent = pathComponents.removeFirst()

        switch pathSegment {
        case .literal(let string):
            if string == firstPathComponent {
                base.append(self)
            }
        case .parameter:
            base.append(self)
        }

        guard !base.isEmpty else {
            return nil
        }

        for child in children {
            guard
                let matching = child.matchingEndpoint(for: pathComponents, method: method),
                !matching.isEmpty,
                matching.last?.willRespond(to: method) == true
                else {
                    continue
            }
            return base + matching
        }


        return nil
    }
}

public enum PathSegment {
    case literal(String)
    case parameter(String)
}
