import struct Foundation.URL
import HTTP
import Core
import Router
import Sparrow

//let server = Server()
//
//try server.start(backlog: 1024) { request in
//    return OutgoingResponse(
//        version: .oneDotOne,
//        status: .ok,
//        headers: ["Content-Length": request.headers["Content-Length"] ?? "0"],
//        cookieHeaders: []
//    ) { stream in
//        let body = try request.body.drain(deadline: .never)
//        try stream.write(body, deadline: .never)
//    }
//}

let contentNegotiator = ContentNegotiator()

let router = Router { root in
//    root.preprocess { request in
//        try contentNegotiator.parse(request, deadline: 1.minute.fromNow())
//    }
    
    root.get { request in
        return Response()
    }
    
//    root.add("echo") { echo in
//        echo.post { request in
//            return Response(content: request.content)
//        }
//    }
//    
//    root.add("foo") { foo in
//        foo.get { request in
//            return Response()
//        }
//        
//        foo.add("bar") { bar in
//            bar.get { request in
//                return Response()
//            }
//        }
//    }
//    
//    root.postprocess { response, request in
//        try contentNegotiator.serialize(response, for: request, deadline: 1.minute.fromNow())
//    }
}

let server = Server()
try server.start(respond: router.respond)
