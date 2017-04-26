import XCTest
@testable import Sparrow

public class SparrowTests: XCTestCase {

    enum TestError: Error {
        case test
    }

    func testServer() throws {

        let router = Router()

        router.add("error") { router in

            router.respond(to: .get) { context in

                if let shouldThrow: Bool = try context.queryParameters.get("throw") {
                    if shouldThrow {
                        throw TestError.test
                    }
                }
                return ResponseContext(
                    status: .ok,
                    message: "Not throwing"
                )
            }
        }

        router.add("echo") { router in

            router.post { context in
                return ResponseContext(
                    status: .ok,
                    content: Content(dictionary: [
                        "message": "Hello world!",
                        "echo": context.content
                    ])
                )
            }
        }

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testHelloWorld() throws {

        let router = Router()

        router.add(
            TestCollection(),
            to: "tests"
        ).add(
            TestEntity(),
            to: .testId
        )

        router.add(UserCollection(), to: "users").add(UserEndpoint(), to: .userId)

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testRouterPerformance() throws {
        let router = Router()
        router.add(UserCollection(), to: "users").add(UserEndpoint(), to: .userId)

        let request = HTTP.Request(method: .get, url: URL(string: "/users")!, headers: ["Authentication": "bearer token"])

        measure {
            print(try? router.respond(to: request))
        }
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}

extension PathParameter {
    public static let userId = PathParameter(rawValue: "userId")
    public static let testId = PathParameter(rawValue: "testId")
}

struct NameAndAgeParameters: ParametersInitializable {

    let age: Int
    let name: String

    init(parameters: Parameters) throws {
        age = try parameters.get("age")
        name = try parameters.get("name")
    }
}
