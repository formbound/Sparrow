import Sparrow

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

public struct UserCollection: EntityCollectionResource {

    public func list(offset: Int, limit: Int?) throws -> EntityCollectionResourceResult<User> {
        let allUsers = (0..<100).map { i in
            return User(
                username: "User \(i)",
                email: "david+\(i)@formbound.com"
            )
        }

        var users = Array(allUsers.suffix(from: offset))

        let limit = limit ?? 10

        users = Array(users[0..<limit])

        return EntityCollectionResourceResult(
            entities: users,
            ofTotal: allUsers.count
        )
    }

}

public struct UserEndpoint: EntityResource {

    public func show(identifier: Int) throws -> User? {
        return User(
            username: "User \(identifier)",
            email: "david+\(identifier)@formbound.com"
        )
    }

}
