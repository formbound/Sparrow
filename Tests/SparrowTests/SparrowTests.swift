import XCTest
@testable import Sparrow
@testable import Core

public class SparrowTests: XCTestCase {

    enum OKError: Error {
        case ok
    }

    func testServer() throws {

        let router = Router()

        router.add(pathComponent: "resource", resource: TestResource())

        router.add(pathComponent: "error") { router in

            router.respond(to: .get) { context in

                if let shouldThrow: Bool = context.queryParameters.value(for: "throw") {
                    if shouldThrow {
                        throw HTTPError(error: .badRequest, reason: "Error")
                    }
                }
                return ResponseContext(
                    status: .ok,
                    message: "Not throwing"
                )
            }
        }

        router.add(pathComponent: "echo") { router in

            router.respond(to: .post) { context in

                return ResponseContext(
                    status: .ok,
                    content: [
                        "message": "Hello world!",
                        "echo": context.payload
                    ]
                )
            }
        }

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testHelloWorld() throws {

        let router = Router()

        router.get {
            context in

            return ResponseContext(
                status: .ok,
                message: "Hello world!"
            )
        }


        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}

struct TestResource: Resource {
    func get(context: RequestContext) throws -> ResponseContext {
        return ResponseContext(
            status: .ok,
            content: User(username: "davidask", email: "david@formbound.com")
        )
    }
}

struct User {
    let username: String
    let email: String
}

extension User: ContentConvertible {
    var content: Content {
        return Content(dictionary: [
            "username": username,
            "email": email
            ])
    }

    init(content: Content) throws {
        self.username = try content.value(forKeyPath: "username")
        self.email = try content.value(forKeyPath: "email")
    }
}
