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
        root.add("users", resource: UsersResource(app: app))
        root.add("profile", route: ProfileRoute(app: app))
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
        users.add("active") { active in
            active.add("today") { today in
                today.get { request in
                    return Response(status: .ok, content: "All users active today")
                }
            }
        }
        
        user.add("photos", resource: UserPhotosResource(app: app))
    }
    
    func list(parameters: NoParameters) throws -> String {
        return "List all users"
    }
    
    func create(parameters: NoParameters, content: NoContent) throws -> String {
        return "Create user"
    }
    
    func removeAll(parameters: NoParameters) throws -> String {
        return "Remove all users"
    }
    
    func show(parameters: UsersParameters) throws -> String {
        return "Show user \(parameters.userID)"
    }
    
    func insert(parameters: UsersParameters, content: NoContent) throws -> String {
        return "Insert user \(parameters.userID)"
    }
    
    func update(parameters: UsersParameters, content: NoContent) throws -> String {
        return "Update user \(parameters.userID)"
    }
    
    func remove(parameters: UsersParameters) throws -> String {
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
    
    func list(parameters: UsersParameters) throws -> String {
        return "List all photos for user \(parameters.userID)"
    }
    
    func create(parameters: UsersParameters, content: NoContent) throws -> String {
        return "Create photo for user \(parameters.userID)"
    }
    
    func removeAll(parameters: UsersParameters) throws -> String {
        return "Remove all photos for user \(parameters.userID)"
    }
    
    func show(parameters: UserPhotoParameters) throws -> String {
        return "Show photo \(parameters.photoID) for user \(parameters.userID)"
    }
    
    func insert(parameters: UserPhotoParameters, content: NoContent) throws -> String {
        return "Insert photo \(parameters.photoID) for user \(parameters.userID)"
    }
    
    func update(parameters: UserPhotoParameters, content: NoContent) throws -> String {
        return "Update photo \(parameters.photoID) for user \(parameters.userID)"
    }
    
    func remove(parameters: UserPhotoParameters) throws -> String {
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
import Crest

class RouterTests : XCTestCase {
    let router = Router(route: root)
    
    let headers: Headers = ["Authorization": "Basic dXNlcm5hbWU6cGFzc3dvcmQ="]
    
    func testIndex() throws {
        let request = Request(
            method: .get,
            url: "/",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Welcome!")
    }
    
    func testShowUserPhoto() throws {
        let request = Request(
            method: .get,
            url: "/users/23/photos/14",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Show photo 14 for user 23")
    }
    
    func testListUsers() throws {
        let request = Request(
            method: .get,
            url: "/users",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "List all users")
    }
    
    func testCreateUser() throws {
        let request = Request(
            method: .post,
            url: "/users",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        response.assert(status: .created)
        response.assert(content: "Create user")
    }
    
    func testShowUser() throws {
        let request = Request(
            method: .get,
            url: "/users/23",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Show user 23")
    }
    
    func testListUserPhotos() throws {
        let request = Request(
            method: .get,
            url: "/users/23/photos",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "List all photos for user 23")
    }
    
    func testShowProfile() throws {
        let request = Request(
            method: .get,
            url: "/profile",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .ok)
        response.assert(content: "Show profile")
    }
    
    func testNotFound() throws {
        let request = Request(
            method: .get,
            url: "/profile/not/found",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .notFound)
    }
    
    func testInvalidParameter() throws {
        let request = Request(
            method: .get,
            url: "/users/invalid-path-parameter",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .badRequest)
    }
    
    func testMethodNotAllowed() throws {
        let request = Request(
            method: .put,
            url: "/users",
            headers: headers
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .methodNotAllowed)
    }
    
    func testAccessDenied() throws {
        let request = Request(
            method: .get,
            url: "/access-denied"
        )!
        
        let response = router.respond(to: request)
        
        response.assert(status: .unauthorized)
    }
    
    func testPerformance() throws {
        let request = Request(
            method: .get,
            url: "/users/active/today",
            headers: headers
        )!
        
        measure {
            _ = self.router.respond(to: request)
        }
    }
    
    func testPerformanceWithPathParameter() {
        let request = Request(
            method: .get,
            url: "/users/23/photos",
            headers: headers
        )!
        
        measure {
            _ = self.router.respond(to: request)
        }
    }
}
