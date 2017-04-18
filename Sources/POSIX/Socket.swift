#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Core


#if os(Linux)
    public enum SocketType : RawRepresentable {
        case stream

        public init?(rawValue: Int32) {
            switch rawValue {
            case Int32(SOCK_STREAM.rawValue):
                self = .stream
            default:
                return nil
            }
        }

        public var rawValue: Int32 {
            switch self {
            case .stream: return Int32(SOCK_STREAM.rawValue)
            }
        }
    }
#else
    public enum SocketType : RawRepresentable {
        case stream

        public init?(rawValue: Int32) {
            switch rawValue {
            case SOCK_STREAM:
                self = .stream
            default:
                return nil
            }
        }

        public var rawValue: Int32 {
            switch self {
            case .stream: return SOCK_STREAM
            }
        }
    }
#endif


public func socket(family: AddressFamily, type: SocketType, `protocol`: Int32) throws -> FileDescriptor {
    let fileDescriptor = socket(family.rawValue, Int32(type.rawValue), `protocol`)
    switch fileDescriptor {
    case -1: throw SystemError.lastOperationError ?? SystemError.unknown
    default: return fileDescriptor
    }
}

public func bind(socket: FileDescriptor, address: Address) throws {
    var address = address
    let result = address.withAddressPointer {
        bind(socket, $0, socklen_t(address.length))
    }

    guard result == 0 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }
}

public func listen(socket: FileDescriptor, backlog: Int) throws {
    let result = listen(socket, Int32(backlog))

    guard result == 0 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }
}

public func accept(socket: FileDescriptor) throws -> (FileDescriptor, Address) {
    var address = Address()
    var length = socklen_t(MemoryLayout<sockaddr>.size)
    let acceptSocket = address.withAddressPointer { pointer in
        accept(socket, pointer, &length)
    }

    guard acceptSocket >= 0 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }

    return (acceptSocket, address)
}

public func connect(socket: FileDescriptor, address: Address) throws {
    var address = address
    let length = socklen_t(MemoryLayout<sockaddr>.size)

    try setNonBlocking(fileDescriptor: socket)

    let result = address.withAddressPointer { addressPointer in
        connect(socket, addressPointer, length)
    }

    guard result == 0 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }
}

public struct SendFlags : OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none  = SendFlags(rawValue: 0)
    #if os(Linux)
        public static let noSignal  = SendFlags(rawValue: Int32(MSG_NOSIGNAL))
    #else
        public static let noSignal  = SendFlags(rawValue: 0)
    #endif
}

public func send(socket: FileDescriptor, bytes: UnsafeRawPointer, count: Int, flags: SendFlags = .none) throws -> Int {
    let result = send(socket, bytes, count, flags.rawValue)

    guard result != -1 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }

    return result
}

public struct ReceiveFlags : OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none  = ReceiveFlags(rawValue: 0)
#if os(Linux)
    public static let noSignal  = ReceiveFlags(rawValue: Int32(MSG_NOSIGNAL))
#else
    public static let noSignal  = ReceiveFlags(rawValue: 0)
#endif
}

public func receive(socket: FileDescriptor, bytes: UnsafeMutableBufferPointer<Byte>, flags: ReceiveFlags = .none) throws -> UnsafeBufferPointer<Byte> {
    let result = recv(socket, bytes.baseAddress!, bytes.count, flags.rawValue)

    guard result != -1 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }

    return UnsafeBufferPointer(start: bytes.baseAddress!, count: bytes.count)
}

public func getAddress(socket: FileDescriptor) throws -> Address {
    return try Address.fromAddressPointer {
        var length = socklen_t(MemoryLayout<sockaddr>.size)
        let result = getsockname(socket, $0, &length)

        guard result == 0 else {
            throw SystemError.lastOperationError ?? SystemError.unknown
        }
    }
}

public func checkError(socket: FileDescriptor) throws {
    var error: Int32 = 0
    var errorSize = socklen_t(MemoryLayout<Int32>.size)

    let result = getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &errorSize)

    guard result == 0 else {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }

    guard error == 0 else {
        throw SystemError(errorNumber: error) ?? .unknown
    }
}

public func setReusePort(socket: FileDescriptor) throws {
    var option: Int32 = 1
    let result = setsockopt(socket, SOL_SOCKET, SO_REUSEPORT, &option, socklen_t(MemoryLayout<Int32>.size))

    if result != 0 {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }
}

public func setReuseAddress(socket: FileDescriptor) throws {
    var option: Int32 = 1
    let result = setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &option, socklen_t(MemoryLayout<Int32>.size))

    if result != 0 {
        throw SystemError.lastOperationError ?? SystemError.unknown
    }
}

#if os(macOS)
    public func setNoSignalOnBrokenPipe(socket: FileDescriptor) throws {
        var option: Int32 = 1
        let result = setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &option, socklen_t(MemoryLayout<Int32>.size))

        if result != 0 {
            throw SystemError.lastOperationError ?? SystemError.unknown
        }
    }
#endif
