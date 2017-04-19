import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {

        let router = Router()

        // Router.root has path component "/"

        // /users
        router.add(pathComponent: "users") { usersRoute in

            usersRoute.add(parameter: "id") { route in

                route.respond(to: .get) { context in

                    guard let id: Int = context.pathParameters.value(for: "id") else {
                        return Response(status: .badRequest, body: "Missing or invalid parameter for id")
                    }

                    return Response(status: .ok, body: "Hello mr \(id)")
                }

            }


            // /users/auth
            // Has no actions, so will not respond with anything, but processes the request
            usersRoute.add(pathComponent: "auth") { route in

                route.processRequest(for: [.get, .post]) { context in
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
                route.add(pathComponent: "facebook") { route in

                    route.respond(to: .get) { context in
                        return Response(status: .ok, body: "Hey, it's me, Facebook")
                    }
                }
            }
        }

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testRouter() throws {
        let users = Router(pathComponent: "users")

        users.actions[.get] = { context in
            return Response(status: .ok)
        }

        let auth = Router(pathComponent: "auth")

        let admin = Router(pathComponent: "admin")

        let authMethod = Router(parameter: "authMethod")

        let login = Router(pathComponent: "login")

        login.actions[.get] = { context in
            return Response(status: .ok)
        }

        let signup = Router(pathComponent: "signup")


        authMethod.add(children: [login, signup])
        auth.add(child: authMethod)
        users.add(child: auth)
        users.add(child: admin)
        
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}




