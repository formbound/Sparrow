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

            router.respond(to: .get) { _ in

                return Router.ViewResponse(
                    status: .ok,
                    view: View(dictionary: ["Hello": "Matey"])
                )
            }
        }

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testSomethingElse() throws {

        var users = View()

        try users.set(value: "David Ask", forKey: "developerName")
        try users.set(value: [1, 2, 3, 4, 5, 6, 7, 8], forKey: "identifiers")

        var view = View(dictionary: [
            "count": 10,
            "users": users
        ])

        let value: String = try view.value(forKeyPath: "users.developerName")
        let values: [Int] = try view.value(forKeyPath: "users.identifiers")

        print(value)
        print(values)

        print(view)

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
