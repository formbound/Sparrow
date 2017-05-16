import XCTest
import HTTP
import Core
@testable import Sparrow

public class SparrowTests : XCTestCase {
    func testEchoServer() throws {

        let router = Router { root in
            
            root.get { request in
                return Response(status: .ok)
            }
            
            root.add(path: "echo") { echo in

                echo.post { request in

                    return try Response(
                        status: .ok,
                        content: request.content(using: request.defaultContentNegotiator),
                        using: request.defaultContentNegotiator
                    )
                }
            }
            
            root.add(path: "foo") { foo in
                foo.get { request in

                    let contentNegotiator = ContentNegotiator(request: request, contentTypes: [.json])

                    return try Response(status: .ok, content: ["Message": "Hello!"], using: contentNegotiator)
                }
                
                foo.add(path: "bar") { bar in
                    bar.get { request in
                        return Response(status: .ok)
                    }

                    bar.add(parameter: "id") { foos in
                        foos.get { request in

                            let contentNegotiator = ContentNegotiator(request: request, contentTypes: .standardTypes)

                            let id: Int = try request.uri.parameters.get("id")

                            return try Response(status: .ok, body: id, using: contentNegotiator)
                        }
                    }
                }
            }

        }

        let server = Server(router: router)
        try server.start()
    }
}

extension Set where Iterator.Element == ContentType {
    static var standardTypes: Set {
        return [.json]
    }
}


extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return [
            ("testEchoServer", testEchoServer)
        ]
    }
}
