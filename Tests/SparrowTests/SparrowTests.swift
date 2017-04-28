import XCTest
import HTTP
@testable import Sparrow

public class SparrowTests : XCTestCase {
    func testEchoServer() throws {
        let contentNegotiator = ContentNegotiator()
        let authenticator = Authenticator()
        
        let router = Router { root in
            root.preprocess { request in
                try authenticator.basicAuth(request, realm: "yo") { username, password in
                    guard username == "username" && password == "password" else {
                        return .accessDenied
                    }
                    
                    return .authenticated
                }
                
                try contentNegotiator.parse(request)
            }
            
            root.add("echo") { echo in
                echo.post { request in
                    return Response(content: request.content)
                }
            }
            
            root.postprocess { response, request in
                try contentNegotiator.serialize(response, for: request)
            }
        }

        let server = try HTTPServer(responder: router)
        try server.start()
    }
}
