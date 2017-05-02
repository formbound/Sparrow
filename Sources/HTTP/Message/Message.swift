import Core

public typealias Storage = [String: Any]

public protocol Message {
    var version: Version { get }
    var headers: Headers { get }
    var storage: Storage { get }
}

extension Message {
    public var contentType: MediaType? {
        return headers["Content-Type"].flatMap({try? MediaType(string: $0)})
    }

    public var contentLength: Int? {
        return headers["Content-Length"].flatMap({Int($0)})
    }

    public var transferEncoding: String? {
        return headers["Transfer-Encoding"]
    }

    public var isChunkEncoded: Bool {
        return transferEncoding == "chunked"
    }

    public var connection: String? {
        return headers["Connection"]
    }

    public var isKeepAlive: Bool {
        if version.minor == 0 {
            return connection?.lowercased() == "keep-alive"
        }

        return connection?.lowercased() != "close"
    }

    public var isUpgrade: Bool {
        return connection?.lowercased() == "upgrade"
    }

    public var upgrade: String? {
        return headers["Upgrade"]
    }
}
