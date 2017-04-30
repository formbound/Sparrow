import Core

public struct OutgoingResponse {
    public typealias Body = (OutputStream) throws -> Void
    
    public var version: Version
    public var status: Status
    public var headers: Headers
    public var cookieHeaders: Set<String>
    public var body: Body
    
    public typealias UpgradeConnection = (IncomingRequest, Stream) throws -> Void
    public var upgradeConnection: UpgradeConnection?
    
    public init(
        version: Version,
        status: Status,
        headers: Headers,
        cookieHeaders: Set<String>,
        body: @escaping Body
    ) {        
        self.version = version
        self.status = status
        self.headers = headers
        self.cookieHeaders = cookieHeaders
        self.body = body
    }
}
