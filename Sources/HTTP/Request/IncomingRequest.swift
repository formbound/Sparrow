import struct Foundation.URL
import Core

public struct IncomingRequest {
    public let method: Method
    public let url: URL
    public let version: Version
    public let headers: Headers
    public let body: InputStream
    
    public typealias UpgradeConnection = (OutgoingResponse, Stream) throws -> Void
    public var upgradeConnection: UpgradeConnection?
    
    public init(
        method: Method,
        url: URL,
        version: Version,
        headers: Headers,
        body: InputStream
    ) {
        self.method = method
        self.url = url
        self.version = version
        self.headers = headers
        self.body = body
    }
}
