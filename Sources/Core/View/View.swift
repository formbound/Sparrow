import Core

public protocol ViewIntitializable {
    init(view: View) throws
}

public protocol ViewRepresentable {
    var view: View { get }
}

public protocol ViewConvertible: ViewIntitializable, ViewRepresentable {}

extension Int: ViewConvertible {
    public var view: View {
        return .int(self)
    }

    public init(view: View) throws {
        guard case .int(let value) = view else {
            throw View.Error.failedViewInitialization(view)
        }

        self = value
    }
}

extension Bool: ViewConvertible {
    public var view: View {
        return .bool(self)
    }

    public init(view: View) throws {
        guard case .bool(let value) = view else {
            throw View.Error.failedViewInitialization(view)
        }

        self = value
    }
}

extension String: ViewConvertible {
    public var view: View {
        return .string(self)
    }

    public init(view: View) throws {
        guard case .string(let value) = view else {
            throw View.Error.failedViewInitialization(view)
        }

        self = value
    }
}

extension Float: ViewConvertible {
    public var view: View {
        return .float(self)
    }

    public init(view: View) throws {
        guard case .float(let value) = view else {
            throw View.Error.failedViewInitialization(view)
        }

        self = value
    }
}

extension Double: ViewConvertible {
    public var view: View {
        return .double(self)
    }

    public init(view: View) throws {
        guard case .double(let value) = view else {
            throw View.Error.failedViewInitialization(view)
        }

        self = value
    }
}

public indirect enum View {

    public enum Error: Swift.Error {
        case illegalNonDictionary(key: String)
        case notFound(keypath: String)
        case illegalType(keyPath: String)
        case failedViewInitialization(View)
    }

    public struct KeyPath: RawRepresentable {
        public var rawValue: [String]

        public init(rawValue: [String]) {
            self.rawValue = rawValue
        }

        public init(path: String) {
            self.rawValue = path.components(separatedBy: ".")
        }
    }

    case int(Int)
    case null
    case bool(Bool)
    case string(String)
    case double(Double)
    case float(Float)
    case array([View])
    case dictionary([String: View])
    case binary([Byte])

    internal init(_ represented: ViewRepresentable) {
        self = represented.view
    }

    public init(dictionary: [String: ViewRepresentable] = [:]) {

        var result: [String: View] = [:]

        for(key, value) in dictionary {
            result[key] = value.view
        }

        self = .dictionary(result)
    }

    public init<T: ViewRepresentable>(array: [T]) {
        self = .array(array.map { $0.view })
    }
}

// MARK: Get values

public extension View {
    internal func value(forKeyPath keyPath: KeyPath) -> View? {

        var keyPath = keyPath

        guard !keyPath.isEmpty else {
            return nil
        }

        guard case .dictionary(let dictionary) = self else {
            return nil
        }

        guard let value = dictionary[keyPath.removeFirst()] else {
            return nil
        }

        guard !keyPath.isEmpty else {
            return value
        }

        return value.value(forKeyPath: keyPath)
    }

    public func value(forKeyPath path: String) -> View? {
        return value(forKeyPath: KeyPath(path: path))
    }

    public mutating func set(value: View?, forKey key: String) throws {
        guard case .dictionary(var dict) = self else {
            throw Error.illegalNonDictionary(key: key)
        }

        dict[key] = value
        self = .dictionary(dict)
    }
}

// MARK: Set values

public extension View {
    public mutating func set(value: ViewRepresentable?, forKey key: String) throws {
        try set(value: value?.view ?? .null, forKey: key)
    }

    public mutating func set(value dictionary: [String: ViewRepresentable?], forKey key: String) throws {

        var result: [String: View] = [:]

        for(key, value) in dictionary {
            result[key] = value?.view ?? .null
        }

        try set(value: .dictionary(result), forKey: key)
    }

    public mutating func set(value array: [ViewRepresentable?], forKey key: String) throws {
        try set(value: .array(array.map { $0?.view ?? .null }), forKey: key)
    }
}

// MARK: Typed accessors, optionals allowed

public extension View {

    public func value<T: ViewIntitializable>(forKeyPath path: String) throws -> T? {
        guard let view = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        if case .null = view {
            return nil
        }

        return try T(view: view)
    }

    public func value(forKeyPath path: String) -> [Byte]? {
        guard let view = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        guard case .binary(let value) = view else {
            return nil
        }

        return value
    }
}

// MARK: - Typed accessors, throwing

public extension View {
    public func value<T: ViewIntitializable>(forKeyPath path: String) throws -> T {
        guard let value: T = try value(forKeyPath: path) else {
            throw Error.notFound(keypath: path)
        }

        return value
    }

    public func value(forKeyPath path: String) throws -> [Byte] {
        guard let value: [Byte] = value(forKeyPath: path) else {
            throw Error.notFound(keypath: path)
        }

        return value
    }
}

// MARK: Typed collection accessors, optionals allowed

public extension View {

    public func value(forKeyPath path: String) -> [View]? {
        guard let view = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        guard case .array(let array) = view else {
            return nil
        }

        return array
    }

    public func value(forKeyPath path: String) -> [String: View]? {
        guard let view = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        guard case .dictionary(let dictionary) = view else {
            return nil
        }

        return dictionary
    }
}

// MARK: Typed collection accessors, throwing

public extension View {
    public func value(forKeyPath path: String) throws -> [View] {
        guard let value: [View] = value(forKeyPath: path) else {
            throw Error.notFound(keypath: path)
        }

        return value
    }

    public func value(forKeyPath path: String) throws -> [String: View] {
        guard let value: [String: View] = value(forKeyPath: path) else {
            throw Error.notFound(keypath: path)
        }

        return value
    }
}

// MARK: Uniformly collection accessors, throwing

public extension View {
    public func value<T: ViewIntitializable>(forKeyPath path: String) throws -> [T] {
        let values: [View] = try value(forKeyPath: path)

        return try values.map { view in
            return try T(view: view)
        }
    }

    public func value(forKeyPath path: String) throws -> [[Byte]] {
        let values: [View] = try value(forKeyPath: path)

        return try values.map { view in
            guard case .binary(let value) = view else {
                throw Error.illegalType(keyPath: path)
            }

            return value
        }
    }
}

extension View.KeyPath: MutableCollection, RangeReplaceableCollection {

    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, C.Iterator.Element == String {
        rawValue.replaceSubrange(subrange, with: newElements)
    }

    public init() {
        self.init(rawValue: [])
    }

    public subscript(position: Int) -> String {
        get {
            return rawValue[position]
        }
        set {
            rawValue[position] = newValue
        }
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return rawValue.count
    }

}

extension View.Error: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .illegalNonDictionary(let key):
            return "Setting values for key(\"\(key)\"), illegal on non-dictionary view"
        case .notFound(let keypath):
            return "Keypath \"\(keypath)\" found"

        case .illegalType(let keypath):
            return "Type of one or more values found at \"\(keypath)\" does not correspond to the inferred type"

        case .failedViewInitialization(let view):
            return "Failed to initialize value with view:\n\(view)"
        }
    }
}

extension View: ViewRepresentable {
    public var view: View {
        return self
    }
}

extension View: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension View: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, ViewRepresentable)...) {
        var result: [String: View] = [:]

        for (key, value) in elements {
            result[key] = value.view
        }

        self.init(dictionary: result)
    }
}

extension View: CustomStringConvertible {
    public var description: String {
        let result: String

        switch self {
        case .int(let int):
            result = String(int)

        case .string(let string):
            result = "\"\(string)\""

        case .double(let double):
            result = String(double)

        case .float(let float):
            result = String(float)

        case .binary(let bytes):
            result = "Binary, \(bytes.count) bytes"

        case .array(let views):
            let descriptions = views.map { view in
                view.description
            }.joined(separator: ", ")

            return "[\(descriptions)]"

        case .dictionary(let dict):

            var components: [String] = []

            for (key, value) in dict {

                components.append(
                    "\(key): \(value.description)"
                )
            }

            result = "{ \(components.joined(separator: ", ")) }"

        case .bool(let bool):
            return bool ? "true" : "false"

        case .null:
            return "<null>"
        }

        return result
    }

}
