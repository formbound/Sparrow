public class ChildComponents<Context : RoutingContext> {
    var pathComponentStrategyChildren: [String: (RouteComponentKey, AnyRouteComponent<Context>)] = [:]
    var parameterStrategyChild: (LosslessStringConvertible.Type, RouteComponentKey, AnyRouteComponent<Context>)? = nil
    
    init() {}
    
    public func add<Component : RouteComponent>(
        _ component: Component,
        forKey key: RouteComponentKey
        ) where Component.ComponentContext == Context {
        switch key.matchingStrategy {
        case let .pathComponent(pathComponent):
            pathComponentStrategyChildren[pathComponent] = (key, AnyRouteComponent(component))
        case let .parameter(type):
            parameterStrategyChild = (type, key, AnyRouteComponent(component))
        }
    }
}
