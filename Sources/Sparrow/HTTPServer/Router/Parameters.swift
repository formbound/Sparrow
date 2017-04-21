import HTTP

public struct Parameters {
    private let contents: [String: String]

    internal init(contents: [String: String] = [:]) {
        self.contents = contents
    }

    public func value<T: ParameterInitializable>(for key: String) -> T? {
        guard let string = contents[key] else {
            return nil
        }

        return try? T(pathParameter: string)
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

extension Int : ParameterConvertible {
    public init(pathParameter: String) throws {
        guard let int = Int(pathParameter) else {
            throw HTTPError(error: .badRequest, reason: "Invalid parameter")
        }
        self.init(int)
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
        default:
            self = false
        }
    }
}
