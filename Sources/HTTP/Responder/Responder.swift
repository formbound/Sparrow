public protocol HTTPResponder {
    func respond(to request: HTTPRequest) -> HTTPResponse
}

public typealias Respond = (_ to: HTTPRequest) -> HTTPResponse
