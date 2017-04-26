public struct PathParameter: RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension Parameters {
    public func get<T: ParameterInitializable>(_ key: PathParameter) throws -> T? {
        return try get(key.rawValue)
    }

    public func get<T: ParameterInitializable>(_ key: PathParameter) throws -> T {
        return try get(key.rawValue)
    }
}
