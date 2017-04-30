import Core
import HTTP
import Venice

public protocol ResponseRepresentable {
    var response: Response { get }
}

public final class Response : Message {
    public var outgoing: OutgoingResponse
    public var content: Content?
    public var storage: Storage = [:]
    
    public init(
        version: Version = .oneDotOne,
        status: Status = .ok,
        headers: Headers = [:],
        cookies: Set<AttributedCookie> = [],
        body: @escaping OutgoingResponse.Body
    ) {
        var cookieHeaders = Set<String>()

        for cookie in cookies {
            cookieHeaders.insert(cookie.description)
        }
        
        self.outgoing = OutgoingResponse(
            version: version,
            status: status,
            headers: headers,
            cookieHeaders: cookieHeaders,
            body: body
        )
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
    public var status: Status {
        get {
            return outgoing.status
        }
        
        set(status) {
            return outgoing.status = status
        }
    }
    
    public var version: Version {
        get {
            return outgoing.version
        }
        
        set(version) {
            outgoing.version = version
        }
    }
    
    public var headers: Headers {
        get {
            return outgoing.headers
        }
        
        set(headers) {
            outgoing.headers = headers
        }
    }
    
    public var body: OutgoingResponse.Body {
        get {
            return outgoing.body
        }
        
        set(body) {
            outgoing.body = body
        }
    }
    
    public var cookies: Set<AttributedCookie> {
        var cookies = Set<AttributedCookie>()

        for header in outgoing.cookieHeaders {
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
