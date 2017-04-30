import XCTest
import HTTP
import Router
@testable import Sparrow

public class SparrowTests : XCTestCase {
    func testEchoServer() throws {
//        let authenticator = Authenticator()
        let contentNegotiator = ContentNegotiator()
        
        let router = Router { root in
            root.preprocess { request in
//                try authenticator.basicAuth(request, realm: "yo") { username, password in
//                    guard username == "username" && password == "password" else {
//                        return .accessDenied
//                    }
//                    
//                    return .authenticated
//                }
                
                try contentNegotiator.parse(request, deadline: 1.minute.fromNow())
            }
            
            root.get { request in
                return Response()
            }
            
            root.add("echo") { echo in
                echo.post { request in
                    return Response(content: request.content)
                }
            }
            
            root.add("foo") { foo in
                foo.get { request in
                    return Response()
                }
                
                foo.add("bar") { bar in
                    bar.get { request in
                        return Response()
                    }
                }
            }
            
            root.postprocess { response, request in
                try contentNegotiator.serialize(response, for: request, deadline: 1.minute.fromNow())
            }
        }

        let server = Server()
        try server.start(respond: router.respond)
    }
}
