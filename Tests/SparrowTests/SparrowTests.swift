import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {

        let router = Router()

        // Router.root has path component "/"

        // /users
        router.root.add(pathComponent: "users") { usersRoute in

            usersRoute.add(parameter: "id") { route in

                route.respond(to: .get) { request, requestParameters in

                    guard let id: Int = requestParameters.value(for: "id") else {
                        return Response(status: .badRequest, body: "Missing or invalid parameter for id")
                    }

                    return Response(status: .ok, body: "Hello mr \(id)")
                }

            }


            // /users/auth
            // Has no actions, so will not respond with anything, but processes the request
            usersRoute.add(pathComponent: "auth") { route in

                route.processRequest(for: [.get, .post]) { request, pathParameters in
                    guard request.headers["content-type"] == "application/json" else {

                        // Return a response, becase the request shouldn't fall through
                        return .break(
                            Response(status: .badRequest, body: "I only accept json")
                        )
                    }

                    // Pass the optionally modified request
                    return .continue(request)
                }

                // /users/auth/facebook
                // Will only be accessed if
                route.add(pathComponent: "facebook") { route in

                    route.respond(to: .get) { request, pathParameters in
                        return Response(status: .ok, body: "Hey, it's me, Facebook")
                    }
                }
            }
        }

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testRoute() throws {
        let users = Route(pathComponent: "users")

        users.actions[.get] = { request, pathParameters in
            return Response(status: .ok)
        }

        let auth = Route(pathComponent: "auth")

        let admin = Route(pathComponent: "admin")

        let authMethod = Route(parameter: "authMethod")

        let login = Route(pathComponent: "login")

        login.actions[.get] = { request, pathParameters in
            return Response(status: .ok)
        }

        let signup = Route(pathComponent: "signup")


        authMethod.add(children: [login, signup])
        auth.add(child: authMethod)
        users.add(child: auth)
        users.add(child: admin)

        print(
            "Result:",
            users.matchingRouteChain(for: ["users", "auth", "facebook", "login"], method: .get)?.debugDescription ?? "Null",
            users.matchingRouteChain(for: ["users"], method: .get)?.debugDescription ?? "Null",
            users.matchingRouteChain(for: ["users", "admin"], method: .get)?.debugDescription ?? "Null"
        )
        
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}
