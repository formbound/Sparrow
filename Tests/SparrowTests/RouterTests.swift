import Sparrow
import HTTP
import Core

// MARK: App Module

protocol Database {}

struct App {
    let database: Database
}

// MARK: Database Module

struct PostgreSQL : Database {}

// MARK: Root Route

struct RootRoute : Route {
    let app: App
    let messageLogger: MessageLogger
    let contentNegotiator: ContentNegotiator
    let authenticator: Authenticator
    
    init(app: App, logger: Logger) {
        self.app = app
        self.messageLogger = MessageLogger(logger: logger)
        self.contentNegotiator = ContentNegotiator()
        self.authenticator = Authenticator()
    }
    
    func configure(router root: Router) {
        root.add(path: "users", resource: UsersResource(app: app))
        root.add(path: "profile", route: ProfileRoute(app: app))
    }
    
    func preprocess(request: Request) throws {
        try authenticator.basic(request) { username, password in
            guard username == "username" && password == "password" else {
                return .accessDenied
            }
            
            return .authenticated
        }
        
        try contentNegotiator.parse(request, deadline: 1.minute.fromNow())
    }
    
    func get(request: Request) throws -> Response {
        return Response(status: .ok, content: "Welcome!")
    }
    
    func postprocess(response: Response, for request: Request) throws {
        try contentNegotiator.serialize(response, for: request, deadline: 1.minute.fromNow())
        messageLogger.log(response, for: request)
    }
}

// MARK: Users Route

struct UsersParameters : ParametersInitializable {
    let userID: Int
    
    init(parameters: Parameters) throws {
        userID = try parameters.get(UsersResource.idKey)
    }
}

struct UsersResource : Resource {
    let app: App
    
    func configure(collectionRouter users: Router, itemRouter user: Router) {
        users.add(path: "active") { active in
            active.add(path: "today") { today in
                today.get { request in
                    return Response(status: .ok, content: "All users active today")
                }
            }
        }
        
        user.add(path: "photos", resource: UserPhotosResource(app: app))
    }
    
    func list(request: Request, parameters: NoParameters) throws -> Content {
        return "List all users"
    }
    
    func create(request: Request, parameters: NoParameters, content: NoContent) throws -> Content {
        return "Create user"
    }
    
    func removeAll(request: Request, parameters: NoParameters) throws -> Content {
        return "Remove all users"
    }
    
    func show(request: Request, parameters: UsersParameters) throws -> Content {
        return "Show user \(parameters.userID)"
    }
    
    func insert(request: Request, parameters: UsersParameters, content: NoContent) throws -> Content {
        return "Insert user \(parameters.userID)"
    }
    
    func update(request: Request, parameters: UsersParameters, content: NoContent) throws -> Content {
        return "Update user \(parameters.userID)"
    }
    
    func remove(request: Request, parameters: UsersParameters) throws -> Content {
        return "Remove user \(parameters.userID)"
    }
}

// MARK: User Photos Route

struct UserPhotoParameters : ParametersInitializable {
    let userID: Int
    let photoID: Int
    
    init(parameters: Parameters) throws {
        userID = try parameters.get(UsersResource.idKey)
        photoID = try parameters.get(UserPhotosResource.idKey)
    }
}

struct UserPhotosResource : Resource {
    let app: App
    
    func list(request: Request, parameters: UsersParameters) throws -> Content {
        return "List all photos for user \(parameters.userID)"
    }
    
    func create(request: Request, parameters: UsersParameters, content: NoContent) throws -> Content {
        return "Create photo for user \(parameters.userID)"
    }
    
    func removeAll(request: Request, parameters: UsersParameters) throws -> Content {
        return "Remove all photos for user \(parameters.userID)"
    }
    
    func show(request: Request, parameters: UserPhotoParameters) throws -> Content {
        return "Show photo \(parameters.photoID) for user \(parameters.userID)"
    }
    
    func insert(request: Request, parameters: UserPhotoParameters, content: NoContent) throws -> Content {
        return "Insert photo \(parameters.photoID) for user \(parameters.userID)"
    }
    
    func update(request: Request, parameters: UserPhotoParameters, content: NoContent) throws -> Content {
        return "Update photo \(parameters.photoID) for user \(parameters.userID)"
    }
    
    func remove(request: Request, parameters: UserPhotoParameters) throws -> Content {
        return "Remove photo \(parameters.photoID) for user \(parameters.userID)"
    }
}

// MARK: Profile Route

struct ProfileRoute : Route {
    let app: App
    
    func put(request: Request) throws -> Response {
        return Response(status: .ok, content: "Insert profile")
    }
    
    func get(request: Request) throws -> Response {
        return Response(status: .ok, content: "Show profile")
    }
    
    func patch(request: Request) throws -> Response {
        return Response(status: .ok, content: "Update profile")
    }
    
    func delete(request: Request) throws -> Response {
        return Response(status: .ok, content: "Remove profile")
    }
}

// MARK: Main Module

let psql = PostgreSQL()
let app = App(database: psql)
let logger = Logger()
let root = RootRoute(app: app, logger: logger)

import XCTest

extension Response {
    public func assert(content otherContent: ContentRepresentable) {
        guard let content = content else {
            return XCTFail("Body is not content")
        }
        
        XCTAssertEqual(content, otherContent.content)
    }
    
    public func assert(status: Status) {
        XCTAssertEqual(self.status, status)
    }
}

class RouterTests : XCTestCase {
    let router = Router(route: root)
    
    let headers: Headers = ["Authorization": "Basic dXNlcm5hbWU6cGFzc3dvcmQ="]
    
    func testIndex() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Welcome!")
    }
    
    func testShowUserPhoto() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/users/23/photos/14"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Show photo 14 for user 23")
    }
    
    func testListUsers() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/users"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "List all users")
    }
    
    func testCreateUser() throws {
        let request = Request(
            method: .post,
            url: URI(path: "/users"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        response.assert(status: .created)
        response.assert(content: "Create user")
    }
    
    func testShowUser() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/users/23"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Show user 23")
    }
    
    func testListUserPhotos() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/users/23/photos"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "List all photos for user 23")
    }
    
    func testShowProfile() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/profile"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Show profile")
    }
    
    func testNotFound() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/profile/not/found"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .notFound)
    }
    
    func testInvalidParameter() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/users/invalid-path-parameter"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .badRequest)
    }
    
    func testMethodNotAllowed() throws {
        let request = Request(
            method: .put,
            url: URI(path: "/users"),
            headers: headers
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .methodNotAllowed)
    }
    
    func testAccessDenied() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/access-denied")
        )
        
        let response = router.respond(to: request)
        
        response.assert(status: .unauthorized)
    }
    
    func testPerformance() throws {
        let request = Request(
            method: .get,
            url: URI(path: "/users/active/today"),
            headers: headers
        )
        
        measure {
            _ = self.router.respond(to: request)
        }
    }
    
    func testPerformanceWithPathParameter() {
        let request = Request(
            method: .get,
            url: URI(path: "/users/23/photos"),
            headers: headers
        )
        
        measure {
            _ = self.router.respond(to: request)
        }
    }
}
