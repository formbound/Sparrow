import Zewo

public enum RouterError : Error {
    case notFound
    case methodNotAllowed
}

extension RouterError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .notFound:
            return Response(status: .notFound)
        case .methodNotAllowed:
            return Response(status: .methodNotAllowed)
        }
    }
}

final public class Router {
    private let root: RouteComponent
    
    public init(root: RouteComponent) {
        self.root = root
    }
    
    public func respond(to request: Request) -> Response {
        var visited: [RouteComponent] = [root]
        let route: [RouteComponent]
        let responder: (Request, Context) throws -> Response
        let context = Context()
        
        do {
            let (matchedRoute, parameters, component) = try match(request: request)
            route = matchedRoute
            responder = try component.responder(for: request)
            context.parameters = parameters
        } catch {
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
    
    private func match(request: Request) throws -> ([RouteComponent], [String: String], RouteComponent) {
        var pathComponents = PathComponents(request.uri.path ?? "/")
        var route: [RouteComponent] = [root]
        var parameters: [String: String] = [:]
        var current = root
        
        while let pathComponent = pathComponents.popPathComponent() {
            if let routeComponent = current.children[pathComponent] {
                route.append(routeComponent)
                parameters[type(of: routeComponent).pathParameterKey] = pathComponent
                current = routeComponent
                continue
            }
            
            let routeComponent = current.pathParameterChild
            
            if !(routeComponent is NoPathParameterChild)  {
                route.append(routeComponent)
                parameters[type(of: routeComponent).pathParameterKey] = pathComponent
                current = routeComponent
                continue
            }
            
            throw RouterError.notFound
        }
        
        return (route, parameters, current)
    }
    
    private func recover(
        error: Error,
        for request: Request,
        context: Context,
        visited: inout [RouteComponent]
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
