import HTTP

public struct Router {

    let routes: [Route]
    var middleware: [Middleware]
    var fallback: Responder

}

extension Router: Responder {
    public func respond(to request: Request) throws -> Response {

        
        fatalError()

        //return try middleware.chain(to: action).respond(to: request)
    }
}
