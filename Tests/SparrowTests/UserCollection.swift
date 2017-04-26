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

public struct UserCollection: CollectionRoute {

    public func list(offset: Int, limit: Int?) throws -> CollectionRouteResult<User> {
        let allUsers = (0..<100).map { i in
            return User(
                username: "User \(i)",
                email: "david+\(i)@formbound.com"
            )
        }

        var users = Array(allUsers.suffix(from: offset))

        let limit = limit ?? 10

        users = Array(users[0..<limit])

        return CollectionRouteResult(
            entities: users,
            ofTotal: allUsers.count
        )
    }

}

public struct UserEndpoint: EntityRoute {
    public struct PathParameters: ParametersInitializable {
        public let id: Int

        public init(parameters: Parameters) throws {
            id = try parameters.get(.userId)
        }
    }

    public func show(pathParameters: UserEndpoint.PathParameters, queryItems: Parameters) throws -> User? {
        return User(
            username: "User \(pathParameters.id)",
            email: "david+\(pathParameters.id)@formbound.com"
        )
    }

}
