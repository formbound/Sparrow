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

    public func value<T: ParameterInitializable>(for key: String) throws -> T? {
        guard let string = contents[key] else {
            return nil
        }

        do {
            return try T(pathParameter: string)
        } catch ParameterConversionError.conversionFailed {
            throw ParametersError.conversionFailed(key)
        } catch {
            throw error
        }
    }

    public func value<T: ParameterInitializable>(for key: String) throws -> T {
        guard let value: T = try value(for: key) else {
            throw ParametersError.missingValue(key)
        }

        return value
    }

    public var isEmpty: Bool {
        return contents.isEmpty
    }
}

public protocol ParameterInitializable {
    init(pathParameter: String) throws
}

public protocol ParameterRepresentable {
    var pathParameter: String { get }
}

public protocol ParameterConvertible: ParameterInitializable, ParameterRepresentable {}

extension String : ParameterConvertible {
    public init(pathParameter: String) throws {
        self = pathParameter
    }

    public var pathParameter: String {
        return self
    }
}

public enum ParameterConversionError: Error {
    case conversionFailed
}

extension Int : ParameterConvertible {
    public init(pathParameter: String) throws {
        guard let value = Int(pathParameter) else {
            throw ParameterConversionError.conversionFailed
        }
        self.init(value)
    }

    public var pathParameter: String {
        return String(self)
    }
}

extension Double : ParameterConvertible {
    public init(pathParameter: String) throws {
        guard let value = Double(pathParameter) else {
            throw ParameterConversionError.conversionFailed
        }
        self.init(value)
    }

    public var pathParameter: String {
        return String(self)
    }
}

extension Float : ParameterConvertible {
    public init(pathParameter: String) throws {
        guard let value = Float(pathParameter) else {
            throw ParameterConversionError.conversionFailed
        }
        self.init(value)
    }

    public var pathParameter: String {
        return String(self)
    }
}

extension Bool : ParameterInitializable {
    public init(pathParameter: String) throws {
        switch pathParameter.lowercased() {
        case "true", "1", "t":
            self = true
        case "false", "0", "f":
            self = false
        default:
            throw ParameterConversionError.conversionFailed
        }
    }
}
