import Foundation

public protocol DataInitializable {
    init(bytes: [Byte]) throws
}

public protocol DataRepresentable {
    var bytes: [Byte] { get }
}

public protocol DataConvertible : DataInitializable, DataRepresentable {}

public enum BufferConversionError: Error {
    case invalidString
}

extension String : DataConvertible {
    public init(bytes: [Byte]) throws {
        guard let string = String(bytes: bytes, encoding: .utf8) else {
            throw BufferConversionError.invalidString
        }
        self = string
    }

    public var bytes: [Byte] {
        return [Byte](self)
    }
}

extension Data: DataConvertible {
    public var bytes: [Byte] {
        return Array(self)
    }
}
