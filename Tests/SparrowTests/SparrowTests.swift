import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    enum OKError: Error {
        case ok
    }

    func testServer() throws {

        let router = Router()


        router.add(pathComponent: "error") { router in

            router.respond(to: .get) { context in
                throw OKError.ok
            }

        }

        // /users
        router.add(pathComponent: "users") { usersRouter in

            usersRouter.add(parameter: "id") { router in

                router.respond(to: .get) { context in

                    guard let id: Int = context.pathParameters.value(for: "id") else {
                        return Response(status: .badRequest, body: "Missing or invalid parameter for id")
                    }

                    return Response(status: .ok, body: "Hello mr \(id)")
                }
            }


            // /users/auth
            // Has no actions, so will not respond with anything, but processes the request
            usersRouter.add(pathComponent: "auth") { router in

                router.preprocess(for: [.get, .post]) { context in
                    guard context.request.headers["content-type"] == "application/json" else {

                        // Return a response, becase the request shouldn't fall through
                        return .break(
                            Response(status: .badRequest, body: "I only accept json")
                        )
                    }

                    // Pass the optionally modified request
                    return .continue
                }

                // /users/auth/facebook
                // Will only be accessed if
                router.add(pathComponent: "facebook") { route in

                    route.respond(to: .get) { context in
                        return Response(status: .ok, body: "Hey, it's me, Facebook")
                    }
                }
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
        
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}




