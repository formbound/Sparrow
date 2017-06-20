public class ContextStorage {
    var parameters: [RouteComponentKey: String]
    var values: [String: Any]
    
    public init() {
        parameters = [:]
        values = [:]
    }
    
    public func set(value: Any?, forKey key: String) {
        values[key] = value
    }
    
    public func value<T>(forKey key: String) throws ->T? {
        guard let value = values[key] else {
            return nil
        }
        
        guard let cast = value as? T else {
            throw RouterError.incompatibleType(requestedType: T.self, actualType: type(of: value))
        }
        
        return cast
    }
    
    public func value<T>(forKey key: String) throws -> T {
        guard let value = values[key] else {
            throw RouterError.valueNotFound(key: key)
        }
        
        guard let cast = value as? T else {
            throw RouterError.incompatibleType(requestedType: T.self, actualType: type(of: value))
        }
        
        return cast
    }
}
