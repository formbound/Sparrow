import XCTest
import HTTP
@testable import Sparrow

public class SparrowTests : XCTestCase {
    func testEchoServer() throws {
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
                    return Response(status: .ok, content: request.content ?? .null)
                }
            }
            
            root.add(path: "foo") { foo in
                foo.get { request in
                    return Response(status: .ok)
                }
                
                foo.add(path: "bar") { bar in
                    bar.get { request in
                        return Response(status: .ok)
                    }
                }
            }
            
            root.postprocess { response, request in
                try contentNegotiator.serialize(response, for: request, deadline: 1.minute.fromNow())
            }
        }

        let server = Server()
//        try server.start(respond: router.respond)
    }
}
