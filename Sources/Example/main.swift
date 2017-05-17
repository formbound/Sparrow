import Foundation
import Core
import HTTP
import Sparrow

var zenCounter = 0

struct RootRoute : Route {
    func configure(route root: RouteConfiguration) {
        root.add(EchoRoute(), subpath: "echo")
        root.add(ZenRoute(), subpath: "zen")
    }
    
    func get(request: Request) throws -> Response {
        let content: Content = [
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
        
        return Response(status: .ok, content: content, contentType: .json)
    }
}

struct EchoRoute : Route {
    let negotiator = ContentNegotiator(contentTypes: .json)
    
    func post(request: Request) throws -> Response {
        let negotiation = try negotiator.negotiate(request)
        let content = try negotiation.getContent()
        return Response(status: .ok, content: content, contentType: negotiation.acceptedType)
    }
}

struct ZenRoute : Route {
    let zen = [
        "Non-blocking is better than blocking.",
        "Anything added dilutes everything else.",
        "Half measures are as bad as nothing at all.",
        "Keep it logically awesome.",
        "Mind your words, they are important.",
        "Approachable is better than simple.",
        "Responsive is better than fast.",
        "Avoid administrative distraction.",
        "It's not fully shipped until it's fast.",
        "Favor focus over features.",
        "Design for failure.",
        "Encourage flow.",
        "Practicality beats purity.",
        "Speak like a human.",
    ]
    
    func get(request: Request) throws -> Response {
        zenCounter += 1
        
        if zenCounter == zen.count {
            zenCounter = 0
        }
        
        return Response(status: .ok, content: zen[zenCounter], contentType: .plainText)
    }
}

let root = RootRoute()
let router = Router(root: root)
let server = Server(router: router)
try server.start()
