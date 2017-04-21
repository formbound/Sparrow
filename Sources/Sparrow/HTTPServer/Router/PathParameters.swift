import HTTP

public struct PathParameters {
    private let contents: [String: String]

    internal init(contents: [String: String] = [:]) {
        self.contents = contents
    }

    public func value<T: PathParameterConvertible>(for key: String) -> T? {
        guard let string = contents[key] else {
            return nil
        }

        return try? T(pathParameter: string)
    }

    public var isEmpty: Bool {
        return contents.isEmpty
    }
}

public protocol PathParameterConvertible {
    init(pathParameter: String) throws
    var pathParameter: String { get }
}

extension String : PathParameterConvertible {
    public init(pathParameter: String) throws {
        self = pathParameter
    }

    public var pathParameter: String {
        return self
    }
}

extension Int : PathParameterConvertible {
    public init(pathParameter: String) throws {
        guard let int = Int(pathParameter) else {
            throw HTTPError(clientError: .badRequest, reason: "Invalid parameter")
        }
        self.init(int)
    }

    public var pathParameter: String {
        return String(self)
    }
}
