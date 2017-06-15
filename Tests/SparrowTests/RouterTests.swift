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

struct Root : RouteComponent {
    let app: Application
    let users: RouteComponent
    
    var children: [PathComponent: RouteComponent] {
        return ["users": users]
    }
    
    init(app: Application) {
        self.app = app
        self.users = UsersComponent(app: app)
    }
}

extension Root : GetResponder {
    func get(request: Request, context: Context) throws -> Response {
        return Response(status: .ok, body: "welcome")
    }
}

struct UsersComponent : RouteComponent {
    let app: Application
    let user: RouteComponent
    
    var children: [PathComponent: RouteComponent] {
        return [.wildcard: user]
    }
    
    init(app: Application) {
        self.app = app
        self.user = UserComponent(app: app)
    }
}

extension UsersComponent : GetResponder {
    struct UsersResponse : Renderable {
        let users: [User]
    }
    
    func get(request: Request, context: Context) throws -> Response {
        let users = UsersResponse(users: app.getUsers())
        return try Response(status: .ok, content: users)
    }
}

extension UsersComponent : PostResponder {
    struct CreateUserRequest : Renderable {
        let firstName: String
        let lastName: String
    }
    
    func post(request: Request, context: Context) throws -> Response {
        let createUser: CreateUserRequest = try request.content()
        let user = app.createUser(firstName: createUser.firstName, lastName: createUser.lastName)
        return try Response(status: .ok, content: user)
    }
}

struct UserComponent : RouteComponent {
    let app: Application
    
    func recover(error: Error, for request: Request, context: Context) throws -> Response {
        switch error {
        case ApplicationError.userNotFound:
            return Response(status: .notFound)
        default:
            throw error
        }
    }
}

extension UserComponent : GetResponder {
    func get(request: Request, context: Context) throws -> Response {
        let id: UUID = try context.pathComponent(for: UserComponent.self)
        let user = try app.getUser(id: id)
        return try Response(status: .ok, content: user)
    }
}

public class RouterTests : XCTestCase {
    let router: Router = {
        let database = Database(url: "psql://localhost/database")
        database.seed()
        let app = Application(database: database)
        let root = Root(app: app)
        return Router(root: root)
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
