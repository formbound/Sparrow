import XCTest
@testable import Sparrow

public class SparrowTests: XCTestCase {

    enum TestError: Error {
        case test
    }

    func testServer() throws {

        let router = Router()

        router.add(pathLiteral: "error") { router in

            router.respond(to: .get) { context in

                if let shouldThrow: Bool = try context.queryParameters.value(for: "throw") {
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

        router.add(pathLiteral: "echo") { router in

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
            resource: TestCollection(),
            toPathLiteral: "tests"
        ).add(
            resource: TestEntity(),
            toParameterName: "id"
        )

        router.add(resource: UserCollection(), toPathLiteral: "users")

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }
}

extension SparrowTests {
    public static var allTests: [(String, (SparrowTests) -> () throws -> Void)] {
        return []
    }
}

struct NameAndAgeParameters: ParametersInitializable {

    let age: Int
    let name: String

    init(parameters: Parameters) throws {
        age = try parameters.value(for: "age")
        name = try parameters.value(for: "name")
    }
}
