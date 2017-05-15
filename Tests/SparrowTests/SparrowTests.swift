import XCTest
import HTTP
@testable import Sparrow

public class SparrowTests : XCTestCase {
    func testEchoServer() throws {

        let router = Router { root in
            
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

        }

        let server = Server(router: router)
//        try server.start()
    }
}


extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return [
            ("testEchoServer", testEchoServer)
        ]
    }
}
