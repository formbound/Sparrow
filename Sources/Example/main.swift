import Foundation
import Core
import Content
import HTTP
import Sparrow

final class RootRoute : Route {
    func configure(route root: RouteConfiguration) {
        root.add("echo", subroute: EchoRoute())
        root.add("zen", subroute: ZenRoute())
    }
    
    func get(request: Request) throws -> Response {
        let content: JSON = [
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
        
        return Response(status: .ok, content: content)
    }
}

struct Echo  {
    let echo: String
}

extension Echo : JSONConvertible, PlainTextConvertible {
    static var contentTypes: ContentTypes = [
        ContentType(Echo.init(json:), Echo.json),
        ContentType(Echo.init(plainText:), Echo.plainText),
    ]

    init(json: JSON) throws {
        echo = try json.get("echo")
    }
    
    func json() -> JSON {
        return ["echo": echo]
    }

    init(plainText: PlainText) throws {
        echo = plainText.description
    }
    
    func plainText() -> PlainText {
        return PlainText(echo)
    }
}

final class EchoRoute : Route {
    func post(request: Request) throws -> Response {
        let content: Echo = try request.content()
        return try Response(status: .ok, content: request.negotiate(content))
    }
}

final class ZenRoute : Route {
    var counter = 0
    
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
        counter += 1
        
        if counter == zen.count {
            counter = 0
        }
        
        let content = PlainText(zen[counter])
        return Response(status: .ok, content: content)
    }
}

let root = RootRoute()
let router = Router(root: root)
let server = Server(router: router)
try server.start()
