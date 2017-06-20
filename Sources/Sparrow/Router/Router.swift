import Zewo

public enum RouterError : Error {
    case notFound
    case methodNotAllowed
    
    case parameterNotFound
    case cannotInitializeParameter(pathComponent: String)
    case invalidParameter
    
    case valueNotFound(key: String)
    case incompatibleType(requestedType: Any.Type, actualType: Any.Type)
}

extension RouterError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .notFound:
            return Response(status: .notFound)
        case .methodNotAllowed:
            return Response(status: .methodNotAllowed)
        case .parameterNotFound:
            return Response(status: .internalServerError)
        case .cannotInitializeParameter:
            return Response(status: .internalServerError)
        case .invalidParameter:
            return Response(status: .badRequest)
        case .valueNotFound:
            return Response(status: .internalServerError)
        case .incompatibleType:
            return Response(status: .internalServerError)
        }
    }
}

final public class Router<Context : RoutingContext> {
    private let root: AnyRouteComponent<Context>
    private let application: Context.Application
    
    public init<Component : RouteComponent>(
        root: Component,
        application: Context.Application
    ) where Component.ComponentContext == Context {
        self.root = AnyRouteComponent(root)
        self.application = application
    }
    
    public func respond(to request: Request) -> Response {
        var visited: [AnyRouteComponent<Context>] = []
        let route: [AnyRouteComponent<Context>]
        let responder: (Request, Context) throws -> Response
        let context = Context(application: application)
        
        do {
            let (matchedRoute, pathComponents, component) = try match(request: request)
            route = matchedRoute
            responder = try component.responder(for: request)
            context.storage.parameters = pathComponents
        } catch {
            visited.append(root)
            return recover(error: error, for: request, context: context, visited: &visited)
        }
        
        do {
            for component in route {
                visited.append(component)
                try component.preprocess(request: request, context: context)
            }
            
            let response = try responder(request, context)
            
            while let component = visited.popLast() {
                try component.postprocess(response: response, for: request, context: context)
            }
            
            return response
        } catch {
            return recover(error: error, for: request, context: context, visited: &visited)
        }
    }
    
    private func match(request: Request) throws -> (
        [AnyRouteComponent<Context>],
        [RouteComponentKey: String],
        AnyRouteComponent<Context>
    ) {
        var components = PathComponents(request.uri.path ?? "/")
        var route: [AnyRouteComponent<Context>] = [root]
        var pathComponents: [RouteComponentKey: String] = [:]
        var current = root
        
        while let pathComponent = components.popPathComponent() {
            if let (key, routeComponent) = try current.child(for: pathComponent) {
                route.append(routeComponent)
                pathComponents[key] = pathComponent
                current = routeComponent
                continue
            }
            
            throw RouterError.notFound
        }
        
        return (route, pathComponents, current)
    }
    
    private func recover(
        error: Error,
        for request: Request,
        context: Context,
        visited: inout [AnyRouteComponent<Context>]
    ) -> Response {
        Logger.error("Error while processing request. Trying to recover.", error: error)
        var lastError = error
        var lastComponent = visited.last
        
        while let component = visited.popLast() {
            lastComponent = component
            
            do {
                let response = try component.recover(error: lastError, for: request, context: context)
                Logger.error("Recovered error.", error: lastError)
                visited.append(component)
                return response
            } catch let error as (Error & ResponseRepresentable) {
                Logger.error("Error can be represented as a response. Recovering.", error: error)
                visited.append(component)
                return error.response
            } catch {
                Logger.error("Error while recovering.", error: error)
                lastError = error
            }
        }
        
        Logger.error("Unrecovered error while processing request.")
        
        if let component = lastComponent {
            visited.append(component)
        }
        
        return Response(status: .internalServerError)
    }
}

fileprivate struct PathComponents {
    private var path: String.CharacterView
    
    fileprivate init(_ path: String) {
        self.path = path.characters.dropFirst()
    }
    
    fileprivate mutating func popPathComponent() -> String? {
        if path.isEmpty {
            return nil
        }
        
        var pathComponent = String.CharacterView()
        
        while let character = path.popFirst() {
            guard character != "/" else {
                break
            }
            
            pathComponent.append(character)
        }
        
        return String(pathComponent)
    }
}

extension Router where Context.Application == Void {
    public convenience init<Component : RouteComponent>(
        root: Component
    ) where Component.ComponentContext == Context {
        self.init(root: root, application: ())
    }
}
