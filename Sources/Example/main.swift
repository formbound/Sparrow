import Core
import HTTP
import Sparrow

struct RootRoute : Route {
    func configure(router root: Router) {
        root.add(path: "echo", route: EchoRoute())
    }
    
    func get(request: Request) throws -> Response {
        return Response(status: .ok)
    }
}

struct EchoRoute : Route {
    let negotiator = ContentNegotiator(contentTypes: .json)
    
    func post(request: Request) throws -> Response {
        let negotiation = try negotiator.negotiate(request, deadline: 5.minutes.fromNow())
        return Response(status: .ok, content: negotiation.content, contentType: negotiation.acceptedType)
    }
}

let root = RootRoute()
let router = Router(root: root)
let server = Server(router: router)
try server.start(port: 9090)
