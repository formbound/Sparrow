import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {

        let router = Router()

        router.root.respond(to: .get) { request in
            return Response(status: .ok, body: "Welcome!")
        }

        router.root.processRequest(for: .get) { request in

            guard request.headers["content-type"] == "application/xml" else {
                return .break(
                    Response(status: .badRequest, body: "Invalid content type")
                )
            }

            return .continue(request)
        }

        let usersRoute = Route(pathComponent: "users")
        usersRoute.respond(to: .get) { request in
            return Response(status: .ok, body: "Lots of users")
        }

        router.root.add(child: usersRoute)

        let log = LogMiddleware()

        let server = try HTTPServer(port: 8080, middleware: [log], responder: router)
        try server.start()
    }

    func testRoute() throws {
        let users = Route(pathComponent: "users")

        users.actions[.get] = BasicResponder { request in
            return Response(status: .ok)
        }

        let auth = Route(pathComponent: "auth")

        let admin = Route(pathComponent: "admin")

        let authMethod = Route(parameter: "authMethod")

        let login = Route(pathComponent: "login")

        login.actions[.get] = BasicResponder { request in
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
