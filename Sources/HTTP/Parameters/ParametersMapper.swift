import Foundation

public enum ParameterError : Error {
    case parameterNotFound(parameterKey: ParameterKey)
    case invalidParameter(parameter: String, type: ParameterInitializable.Type)
}

extension ParameterError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case .parameterNotFound:
            return Response(status: .internalServerError)
        case .invalidParameter:
            return Response(status: .badRequest)
        }
    }
}

public protocol ParameterMappable {
    init(mapper: ParameterMapper) throws
}

public final class ParameterMapper {
    var parameters: [String: String]
    
    init(parameters: [String: String] = [:]) {
        self.parameters = parameters
    }
    
    func set(_ parameter: String, for parameterKey: String) {
        parameters[parameterKey] = parameter
    }
    
    public func get<P : ParameterInitializable>(_ parameterKey: ParameterKey) throws -> P {
        guard let parameter = parameters[parameterKey.key] else {
            throw ParameterError.parameterNotFound(parameterKey: parameterKey)
        }
        
        do {
            return try P(parameter: parameter)
        } catch {
            throw ParameterError.invalidParameter(parameter: parameter, type: P.self)
        }
    }
}

extension ParameterMapper {
    convenience init(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            self.init()
            return
        }
        
        guard let queryItems = components.queryItems else {
            self.init()
            return
        }
        
        var parameters: [String: String] = [:]
        
        for queryItem in queryItems {
            parameters[queryItem.name] = queryItem.value ?? ""
        }
        
        self.init(parameters: parameters)
    }
}
