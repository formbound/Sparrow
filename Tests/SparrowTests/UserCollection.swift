@testable import Sparrow

public struct User {
    let username: String
    let email: String
}

extension User: ContentConvertible {
    public var content: Content {
        return Content(dictionary: [
            "username": username,
            "email": email
            ])
    }

    public init(content: Content) throws {
        self.username = try content.value(forKeyPath: "username")
        self.email = try content.value(forKeyPath: "email")
    }
}

public struct UserCollection: ResourceCollection {

    public func get(offset: Int, limit: Int?) throws -> ResourceCollectionResult<User> {

        let allUsers = (0..<100).map { i in
            return User(
                username: "User \(i)",
                email: "david+\(i)@formbound.com"
            )
        }

        var users = Array(allUsers.suffix(from: offset))

        let limit = limit ?? 10

        users = Array(users[0..<limit])

        return ResourceCollectionResult(
            elements: users, totalElementCount: allUsers.count, limit: limit, offset: offset)
    }
}
