import Foundation

// MARK: ParameterKey

public struct ParameterKey {
    let key: String
    
    public init(_ key: String) {
        self.key = key
    }
}

extension ParameterKey : ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

// MARK: ParameterInitializable

public protocol ParameterInitializable {
    init(parameter: String) throws
}

// MARK: Parameters

public struct NoParameters : ParameterMappable {
    public init(mapper: ParameterMapper) throws {}
}

extension String : ParameterInitializable {
    public init(parameter: String) throws {
        self = parameter
    }
}

extension Int : ParameterInitializable {
    public init(parameter: String) throws {
        guard let int = Int(parameter) else {
            throw RouterError.invalidParameter(parameter: parameter, type: type(of: self))
        }
        
        self.init(int)
    }
}

extension UUID : ParameterInitializable {
    public init(parameter: String) throws {
        guard let uuid = UUID(uuidString: parameter) else {
            throw RouterError.invalidParameter(parameter: parameter, type: type(of: self))
        }
        
        self.init(uuid: uuid.uuid)
    }
}

extension Double : ParameterInitializable {
    public init(parameter: String) throws {
        guard let double = Double(parameter) else {
            throw RouterError.invalidParameter(parameter: parameter, type: type(of: self))
        }
        
        self.init(double)
    }
}

extension Float : ParameterInitializable {
    public init(parameter: String) throws {
        guard let float = Float(parameter) else {
            throw RouterError.invalidParameter(parameter: parameter, type: type(of: self))
        }
        
        self.init(float)
    }
}

extension Bool : ParameterInitializable {
    public init(parameter: String) throws {
        switch parameter.lowercased() {
        case "true", "1", "t":
            self = true
        case "false", "0", "f":
            self = false
        default:
            throw RouterError.invalidParameter(parameter: parameter, type: type(of: self))
        }
    }
}
