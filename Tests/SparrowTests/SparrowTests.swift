import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {
        let log = LogMiddleware()

        let router = BasicRouter { route in
            route.get("/hello") { request in
                return Response(body: "Hello, world! 👾")
            }

            route.fallback = BasicResponder { request in
                Response(status: .notFound, body: "Fallback: not found")
            }
        }

        let server = try HTTPServer(port: 8080, middleware: [log], responder: router)
        try server.start()
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}
