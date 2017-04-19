import XCTest
@testable import Sparrow

public class SparrowTests : XCTestCase {

    func testServer() throws {

    }

    func testRoute() throws {
        var users = Route(pathComponent: "users")

        users.actions[.get] = BasicResponder { request in
            return Response(status: .ok)
        }

        var auth = Route(pathComponent: "auth")

        let admin = Route(pathComponent: "admin")

        var authMethod = Route(parameter: "authMethod")

        let login = Route(pathComponent: "login")

        let signup = Route(pathComponent: "signup")


        authMethod.children += [login, signup]
        auth.children.append(authMethod)
        users.children.append(auth)
        users.children.append(admin)

        print(
            "Result:",
            users.matchingEndpoint(for: ["users", "auth", "facebook", "login"], method: .get),
            users.matchingEndpoint(for: ["users"], method: .get),
            users.matchingEndpoint(for: ["users", "admin"], method: .get)
        )
        
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}
