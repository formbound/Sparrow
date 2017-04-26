import HTTP

enum ParametersError: Error {
    case missingValue(String)
    case conversionFailed(String)
}

public protocol ParametersInitializable {
    init(parameters: Parameters) throws
}

public struct Parameters {
    private let contents: [String: String]

    internal init(contents: [String: String] = [:]) {
        self.contents = contents
    }

    public func get<T: ParameterInitializable>(_ key: String) throws -> T? {
        guard let string = contents[key] else {
            return nil
        }

        do {
            return try T(parameter: string)
        } catch ParameterConversionError.conversionFailed {
            throw ParametersError.conversionFailed(key)
        } catch {
            throw error
        }
    }

    public func get<T: ParameterInitializable>(_ key: String) throws -> T {
        guard let value: T = try get(key) else {
            throw ParametersError.missingValue(key)
        }

        return value
    }

    public var isEmpty: Bool {
        return contents.isEmpty
    }

    public static let empty = Parameters(contents: [:])
}

public protocol ParameterInitializable {
    init(parameter: String) throws
}

public protocol ParameterRepresentable {
    var parameter: String { get }
}

public protocol ParameterConvertible: ParameterInitializable, ParameterRepresentable {}

extension String : ParameterConvertible {
    public init(parameter: String) throws {
        self = parameter
    }

    public var parameter: String {
        return self
    }
}

public enum ParameterConversionError: Error {
    case conversionFailed
}

extension Int : ParameterConvertible {
    public init(parameter: String) throws {
        guard let value = Int(parameter) else {
            throw ParameterConversionError.conversionFailed
        }
        self.init(value)
    }

    public var parameter: String {
        return String(self)
    }
}

extension Double : ParameterConvertible {
    public init(parameter: String) throws {
        guard let value = Double(parameter) else {
            throw ParameterConversionError.conversionFailed
        }
        self.init(value)
    }

    public var parameter: String {
        return String(self)
    }
}

extension Float : ParameterConvertible {
    public init(parameter: String) throws {
        guard let value = Float(parameter) else {
            throw ParameterConversionError.conversionFailed
        }
        self.init(value)
    }

    public var parameter: String {
        return String(self)
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
            throw ParameterConversionError.conversionFailed
        }
    }
}
