import Core

public enum ContentError : Error {
    case illegalNonDictionary(key: String)
    case notFound(keypath: String)
    case illegalType(keyPath: String)
    case failedContentInitialization(Content)
}

public protocol ContentInitializable {
    init(content: Content) throws
}

public protocol ContentRepresentable : ResponseRepresentable {
    var content: Content { get }
}

extension ContentRepresentable {
    public var response: Response {
        return Response(content: content)
    }
}

public protocol ContentConvertible : ContentInitializable, ContentRepresentable {}

extension Int : ContentConvertible {
    public var content: Content {
        return .int(self)
    }

    public init(content: Content) throws {
        guard case .int(let value) = content else {
            throw ContentError.failedContentInitialization(content)
        }

        self = value
    }
}

extension Bool : ContentConvertible {
    public var content: Content {
        return .bool(self)
    }

    public init(content: Content) throws {
        guard case .bool(let value) = content else {
            throw ContentError.failedContentInitialization(content)
        }

        self = value
    }
}

extension String : ContentConvertible {
    public var content: Content {
        return .string(self)
    }

    public init(content: Content) throws {
        guard case .string(let value) = content else {
            throw ContentError.failedContentInitialization(content)
        }

        self = value
    }
}

extension Float : ContentConvertible {
    public var content: Content {
        return .float(self)
    }

    public init(content: Content) throws {
        guard case .float(let value) = content else {
            throw ContentError.failedContentInitialization(content)
        }

        self = value
    }
}

extension Double : ContentConvertible {
    public var content: Content {
        return .double(self)
    }

    public init(content: Content) throws {
        guard case .double(let value) = content else {
            throw ContentError.failedContentInitialization(content)
        }

        self = value
    }
}

public indirect enum Content {
    public struct KeyPath : RawRepresentable {
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
    case array([Content])
    case dictionary([String: Content])
    case binary([Byte])

    internal init(_ represented: ContentRepresentable) {
        self = represented.content
    }

    public init() {
        self.init(dictionary: [:])
    }

    public init(dictionary: [String: ContentRepresentable?] = [:]) {

        var result: [String: Content] = [:]

        for(key, value) in dictionary {
            result[key] = value?.content ?? .null
        }

        self = .dictionary(result)
    }

    public init<T: ContentRepresentable>(array: [T]) {
        self = .array(array.map { $0.content })
    }
}

extension Content {
    public var isEmpty: Bool {
        switch self {
        case .array(let content):
            return content.isEmpty
        case .dictionary(let dict):
            return dict.isEmpty
        default:
            return false
        }
    }
}

// MARK: Get values

public extension Content {
    internal func value(forKeyPath keyPath: KeyPath) -> Content? {

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

    public func value(forKeyPath path: String) -> Content? {
        return value(forKeyPath: KeyPath(path: path))
    }
}

// MARK: Set values

public extension Content {

    public mutating func set(value: Content?, forKey key: String) throws {
        guard case .dictionary(var dict) = self else {
            throw ContentError.illegalNonDictionary(key: key)
        }

        dict[key] = value
        self = .dictionary(dict)
    }

    public mutating func set(value: ContentRepresentable?, forKey key: String) throws {
        try set(value: value?.content ?? .null, forKey: key)
    }

    public mutating func set(value dictionary: [String: ContentRepresentable?], forKey key: String) throws {

        var result: [String: Content] = [:]

        for(key, value) in dictionary {
            result[key] = value?.content ?? .null
        }

        try set(value: .dictionary(result), forKey: key)
    }

    public mutating func set(value array: [ContentRepresentable?], forKey key: String) throws {
        try set(value: .array(array.map { $0?.content ?? .null }), forKey: key)
    }
}

// MARK: Typed accessors, optionals allowed

public extension Content {

    public func value<T: ContentInitializable>(forKeyPath path: String) throws -> T? {
        guard let content = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        if case .null = content {
            return nil
        }

        return try T(content: content)
    }

    public func value(forKeyPath path: String) -> [Byte]? {
        guard let content = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        guard case .binary(let value) = content else {
            return nil
        }

        return value
    }
}

// MARK: - Typed accessors, throwing

public extension Content {
    public func value<T: ContentInitializable>(forKeyPath path: String) throws -> T {
        guard let value: T = try value(forKeyPath: path) else {
            throw ContentError.notFound(keypath: path)
        }

        return value
    }

    public func value(forKeyPath path: String) throws -> [Byte] {
        guard let value: [Byte] = value(forKeyPath: path) else {
            throw ContentError.notFound(keypath: path)
        }

        return value
    }
}

// MARK: Typed collection accessors, optionals allowed

public extension Content {

    public func value(forKeyPath path: String) -> [Content]? {
        guard let content = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        guard case .array(let array) = content else {
            return nil
        }

        return array
    }

    public func value(forKeyPath path: String) -> [String: Content]? {
        guard let content = value(forKeyPath: KeyPath(path: path)) else {
            return nil
        }

        guard case .dictionary(let dictionary) = content else {
            return nil
        }

        return dictionary
    }
}

// MARK: Typed collection accessors, throwing

public extension Content {
    public func value(forKeyPath path: String) throws -> [Content] {
        guard let value: [Content] = value(forKeyPath: path) else {
            throw ContentError.notFound(keypath: path)
        }

        return value
    }

    public func value(forKeyPath path: String) throws -> [String: Content] {
        guard let value: [String: Content] = value(forKeyPath: path) else {
            throw ContentError.notFound(keypath: path)
        }

        return value
    }
}

// MARK: Uniformly collection accessors, throwing

public extension Content {
    public func value<T: ContentInitializable>(forKeyPath path: String) throws -> [T] {
        let values: [Content] = try value(forKeyPath: path)

        return try values.map { content in
            return try T(content: content)
        }
    }

    public func value(forKeyPath path: String) throws -> [[Byte]] {
        let values: [Content] = try value(forKeyPath: path)

        return try values.map { content in
            guard case .binary(let value) = content else {
                throw ContentError.illegalType(keyPath: path)
            }

            return value
        }
    }
}

extension Content.KeyPath : MutableCollection, RangeReplaceableCollection {

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

extension ContentError : CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .illegalNonDictionary(let key):
            return "Setting values for key(\"\(key)\"), illegal on non-dictionary content"
        case .notFound(let keypath):
            return "Keypath \"\(keypath)\" found"

        case .illegalType(let keypath):
            return "Type of one or more values found at \"\(keypath)\" does not correspond to the inferred type"

        case .failedContentInitialization(let content):
            return "Failed to initialize value with content:\n\(content)"
        }
    }
}

extension Content : ContentRepresentable {
    public var content: Content {
        return self
    }
}

extension Content : ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension Content : CustomStringConvertible {
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

        case .array(let content):
            let descriptions = content.map { content in
                content.description
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

extension Content : Equatable {}

public func == (lhs: Content, rhs: Content) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null): return true
    case let (.int(l), .int(r)) where l == r: return true
    case let (.bool(l), .bool(r)) where l == r: return true
    case let (.string(l), .string(r)) where l == r: return true
    case let (.binary(l), .binary(r)) where l == r: return true
    case let (.double(l), .double(r)) where l == r: return true
    case let (.array(l), .array(r)) where l == r: return true
    case let (.dictionary(l), .dictionary(r)) where l == r: return true
    default: return false
    }
}
