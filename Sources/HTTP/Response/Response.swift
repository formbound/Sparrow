import Core
import Venice

public protocol ResponseRepresentable {
    var response: Response { get }
}

public final class Response : Message {
    public typealias Body = (OutputStream) throws -> Void
    
    public var version: Version
    public var status: Status
    public var headers: Headers
    public var cookieHeaders: Set<String>
    public var body: Body
    
    public typealias UpgradeConnection = (Request, Stream) throws -> Void
    public var upgradeConnection: UpgradeConnection?
    
    public var content: Content?
    public var storage: Storage = [:]
    
    public init(
        version: Version = .oneDotOne,
        status: Status = .ok,
        headers: Headers = [:],
        cookies: Set<AttributedCookie> = [],
        body: @escaping Body
    ) {
        var cookieHeaders = Set<String>()

        for cookie in cookies {
            cookieHeaders.insert(cookie.description)
        }
        
        self.version = version
        self.status = status
        self.headers = headers
        self.cookieHeaders = cookieHeaders
        self.body = body
    }
}

extension Response {
    public convenience init(
        version: Version = .oneDotOne,
        status: Status = .ok,
        headers: Headers = [:],
        cookies: Set<AttributedCookie> = [],
        content: Content? = nil
    ) {
        self.init(
            version: version,
            status: status,
            headers: headers,
            cookies: cookies,
            body: { _ in }
        )
        
        self.content = content
        
        if content == nil {
            self.headers.contentLength = 0
        }
    }

    public convenience init(
        version: Version = .oneDotOne,
        status: Status = .ok,
        headers: Headers = [:],
        cookies: Set<AttributedCookie> = [],
        content: ContentRepresentable
    ) {
        self.init(
            version: version,
            status: status,
            headers: headers,
            cookies: cookies,
            content: content.content as Content
        )
    }
}

extension Response {
    public var cookies: Set<AttributedCookie> {
        var cookies = Set<AttributedCookie>()

        for header in cookieHeaders {
            if let cookie = AttributedCookie(header) {
                cookies.insert(cookie)
            }
        }
        
        return cookies
    }
}

extension Response : ResponseRepresentable {
    public var response: Response {
        return self
    }
}

extension Response : CustomStringConvertible {
    public var statusLineDescription: String {
        return
            "HTTP/" + version.description + " " +
            status.description + "\n"
    }
    
    public var description: String {
        return
            statusLineDescription +
            headers.description + "\n" +
            (content?.description ?? "")
    }
}
