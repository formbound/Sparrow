public protocol Responder {
    func respond(to request: Request) throws -> Response
}


public typealias Respond = (_ to: Request) throws -> Response

public struct BasicResponder : Responder {
    let respond: Respond

    public init(_ respond: @escaping Respond) {
        self.respond = respond
    }

    public func respond(to request: Request) throws -> Response {
        return try self.respond(request)
    }
}
