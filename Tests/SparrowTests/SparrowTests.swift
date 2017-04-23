import XCTest
@testable import Sparrow
@testable import Core

public class SparrowTests: XCTestCase {

    enum TestError: Error {
        case test
    }

    func testServer() throws {

        let router = Router()

        router.add(pathComponent: "resource", resource: TestResource())

        router.add(pathComponent: "error") { router in

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

        router.add(pathComponent: "echo") { router in

            router.post { context in
                return ResponseContext(
                    status: .ok,
                    content: [
                        "message": "Hello world!",
                        "echo": context.content
                    ]
                )
            }
        }

        let server = try HTTPServer(port: 8080, responder: router)
        try server.start()
    }

    func testHelloWorld() throws {

        let router = Router()
        router.add(pathComponent: "greeting") { router in
            router.add(parameterName: "name") { router in
                router.get { context in
                    return try ResponseContext(
                        status: .ok,
                        message: "Hello " + context.pathParameters.value(for: "name")
                    )
                }

                router.add(parameterName: "age") { router in

                    router.get { context in

                        let parameters = try NameAndAgeParameters(parameters: context.pathParameters)

                        return ResponseContext(
                            status: .ok,
                            message: "Hello " + parameters.name + ". Your age is " + String(parameters.age)
                        )
                    }

                }
            }
        }
        // GET /
        router.get { _ in
            return ResponseContext(
                status: .ok,
                message: "Hello world!"
            )
        }

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

struct TestResource: Resource {
    func get(context: RequestContext) throws -> ResponseContext {
        return ResponseContext(
            status: .ok,
            content: User(username: "davidask", email: "david@formbound.com")
        )
    }
}

struct User {
    let username: String
    let email: String
}

extension User: ContentConvertible {
    var content: Content {
        return Content(dictionary: [
            "username": username,
            "email": email
            ])
    }

    init(content: Content) throws {
        self.username = try content.value(forKeyPath: "username")
        self.email = try content.value(forKeyPath: "email")
    }
}
