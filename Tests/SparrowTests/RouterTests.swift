import XCTest
import Sparrow

struct User : Renderable {
    let id: UUID
    let firstName: String
    let lastName: String
}

final class Database {
    let url: String
    var users: [UUID: User] = [:]
    
    init(url: String) {
        self.url = url
    }
    
    func seed() {
        let david = User(id: UUID(), firstName: "David", lastName: "Ask")
        saveUser(user: david)
    }
    
    func getUsers() -> [User] {
        return Array(users.values.sorted(by: { $0.lastName < $1.lastName }))
    }
    
    func saveUser(user: User) {
        users[user.id] = user
    }
    
    func getUser(id: UUID) -> User? {
        return users[id]
    }
}

enum ApplicationError : Error {
    case userNotFound
}

final class Application {
    let database: Database

    init(database: Database) {
        self.database = database
        database.seed()
    }
    
    func getUsers() -> [User] {
        return database.getUsers()
    }
    
    func createUser(firstName: String, lastName: String) -> User {
        let user = User(id: UUID(), firstName: firstName, lastName: lastName)
        database.saveUser(user: user)
        return user
    }
    
    func getUser(id: UUID) throws -> User {
        guard let user = database.getUser(id: id) else {
            throw ApplicationError.userNotFound
        }
        
        return user
    }
}

final class Context : RoutingContext {
    let storage = ContextStorage()
    let app: Application
    
    init(application: Application) {
        self.app = application
    }
}

extension RouteComponentKey {
    static let users: RouteComponentKey = "users"
    static let userID: RouteComponentKey = .parameter(UUID.self)
}

struct RootComponent : RouteComponent {
    let users = UsersComponent()
    
    func configure(children: ChildComponents<Context>) {
        children.add(users, forKey: .users)
    }

    func get(request: Request, context: Context) throws -> Response {
        return Response(status: .ok, body: "welcome")
    }
}

struct UsersComponent : RouteComponent {
    let user = UserComponent()

    func configure(children: ChildComponents<Context>) {
        children.add(user, forKey: .userID)
    }

    struct UsersResponse : Renderable {
        let users: [User]
    }
    
    func get(request: Request, context: Context) throws -> Response {
        let users = UsersResponse(users: context.app.getUsers())
        return try Response(status: .ok, content: users)
    }
    
    struct CreateUserRequest : Renderable {
        let firstName: String
        let lastName: String
    }
    
    func post(request: Request, context: Context) throws -> Response {
        let createUser: CreateUserRequest = try request.content()
        
        let user = context.app.createUser(
            firstName: createUser.firstName,
            lastName: createUser.lastName
        )
        
        return try Response(status: .ok, content: user)
    }
}

struct UserComponent : RouteComponent {
    func get(request: Request, context: Context) throws -> Response {
        let id: UUID = try context.parameter(forKey: .userID)
        let user = try context.app.getUser(id: id)
        return try Response(status: .ok, content: user)
    }
    
    func recover(error: Error, for request: Request, context: Context) throws -> Response {
        switch error {
        case ApplicationError.userNotFound:
            return Response(status: .notFound)
        default:
            throw error
        }
    }
}

public class RouterTests : XCTestCase {
    let router: Router<Context> = {
        let database = Database(url: "psql://localhost/database")
        let application = Application(database: database)
        let root = RootComponent()
        return Router(root: root, application: application)
    }()
    
    func testRouter() throws {
        var request: Request
        var response: Response
        
        request = try Request(method: .get, uri: "/")
        response = router.respond(to: request)
        XCTAssertEqual(response.status, .ok)
        
        request = try Request(method: .options, uri: "/")
        response = router.respond(to: request)
        XCTAssertEqual(response.status, .methodNotAllowed)
        
        request = try Request(method: .get, uri: "/not-found")
        response = router.respond(to: request)
        XCTAssertEqual(response.status, .notFound)
        
        request = try Request(method: .get, uri: "/users")
        response = router.respond(to: request)
        var usersResponse: UsersComponent.UsersResponse = try response.content()
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(usersResponse.users.count, 1)
        var id = usersResponse.users[0].id
        XCTAssertEqual(usersResponse.users[0].firstName, "David")
        XCTAssertEqual(usersResponse.users[0].lastName, "Ask")
        
        request = try Request(method: .get, uri: "/users/\(id)")
        response = router.respond(to: request)
        let david: User = try response.content()
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(david.id, id)
        XCTAssertEqual(david.firstName, "David")
        XCTAssertEqual(david.lastName, "Ask")
        
        request = try Request(method: .get, uri: "/users/\(UUID())")
        response = router.respond(to: request)
        XCTAssertEqual(response.status, .notFound)
        
        let createUserRequest = UsersComponent.CreateUserRequest(firstName: "Paulo", lastName: "Faria")
        request = try Request(method: .post, uri: "/users", content: createUserRequest)
        response = router.respond(to: request)
        var paulo: User = try response.content()
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(paulo.firstName, "Paulo")
        XCTAssertEqual(paulo.lastName, "Faria")
        
        request = try Request(method: .get, uri: "/users")
        response = router.respond(to: request)
        usersResponse = try response.content()
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(usersResponse.users.count, 2)
        XCTAssertEqual(usersResponse.users[0].firstName, "David")
        XCTAssertEqual(usersResponse.users[0].lastName, "Ask")
        XCTAssertEqual(usersResponse.users[1].firstName, "Paulo")
        XCTAssertEqual(usersResponse.users[1].lastName, "Faria")
        
        id = paulo.id
        request = try Request(method: .get, uri: "/users/\(paulo.id)")
        response = router.respond(to: request)
        paulo = try response.content()
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(paulo.id, id)
        XCTAssertEqual(paulo.firstName, "Paulo")
        XCTAssertEqual(paulo.lastName, "Faria")
    }
    
    public static var allTests = [
        ("test", testRouter),
    ]
}
