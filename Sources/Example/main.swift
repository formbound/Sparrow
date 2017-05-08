import HTTP
import Sparrow
import Foundation

let server = Server()
let contentNegotiator = ContentNegotiator()

let router = Router { root in
    root.preprocess { request in
        try contentNegotiator.parse(request, deadline: 1.minute.fromNow())
    }
    
    root.get { request in
        return Response(status: .ok)
    }
    
    root.add(path: "echo") { echo in
        echo.post { request in
            return Response(
                status: .ok,
                headers: ["Transfer-Encoding": "chunked"],
                content: request.content ?? .null
            )
        }
    }
    
    root.add(path: "foo") { foo in
        foo.get { request in
            return Response(status: .ok)
        }
        
        foo.add(path: "bar") { bar in
            bar.get { request in
                return Response(status: .ok, content: "yo")
            }
        }
    }
    
    root.postprocess { response, request in
        try contentNegotiator.serialize(response, for: request, deadline: 1.minute.fromNow())
    }
}

try server.start(respond: router.respond)






