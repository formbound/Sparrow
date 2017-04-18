import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {
        let log = LogMiddleware()

        let router = BasicRouter { route in
            route.get("/") { request in
                return Response(body: "Hello, world!")
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
