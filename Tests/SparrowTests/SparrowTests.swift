import XCTest
@testable import Sparrow
@testable import Core

public class SparrowTests: XCTestCase {

    enum OKError: Error {
        case ok
    }

    func testServer() throws {

        let router = Router()

        router.add(pathComponent: "error") { router in

            router.respond(to: .get) { context in

                if let shouldThrow: Bool = context.queryParameters.value(for: "throw") {
                    if shouldThrow {
                        throw HTTPError(error: .badRequest, reason: "Error")
                    }
                }
                return Payload(
                    status: .ok,
                    view: ["message": "Success"]
                )
            }
        }

        router.add(pathComponent: "echo") { router in

            router.respond(to: .post) { context in

                return Payload(
                    status: .ok,
                    view: [
                        "message": "Hello world!",
                        "echo": context.payload
                    ]
                )
            }
        }

        let server = try HTTPServer(port: 8080, router: router)
        try server.start()
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}


struct User {
    let username: String
    let email: String
}

extension User: ViewConvertible {
    var view: View {
        return View(dictionary: [
            "username": username,
            "email": email
            ])
    }

    init(view: View) throws {
        self.username = try view.value(forKeyPath: "username")
        self.email = try view.value(forKeyPath: "email")
    }
}
