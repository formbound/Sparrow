import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {

        let router = Router()


        router.add(pathComponent: "error") { router in

            router.respond(to: .get) { context in
                throw HTTPError.badRequest
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

        let server = try HTTPServer(port: 8181, responder: router)
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




