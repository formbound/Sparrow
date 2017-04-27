public protocol HTTPResponder: ResponderRepresentable {
    func respond(to request: HTTPRequest) throws -> HTTPResponse
}

extension HTTPResponder {
    public var responder: HTTPResponder {
        return self
    }
}

public protocol ResponderRepresentable {
    var responder: HTTPResponder { get }
}

public typealias Respond = (_ to: HTTPRequest) throws -> HTTPResponse

public struct BasicResponder: HTTPResponder {
    let respond: Respond

    public init(_ respond: @escaping Respond) {
        self.respond = respond
    }

    public func respond(to request: HTTPRequest) throws -> HTTPResponse {
        return try self.respond(request)
    }
}
