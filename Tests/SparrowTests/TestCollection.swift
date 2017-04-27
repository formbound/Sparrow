@testable import Sparrow

public class TestCollection: Route {

    public func get(request: Request) throws -> Response {
        return Response(
            status: .ok,
            message: "All tests"
        )
    }
}

public class TestEntity: Route {

    public func get(request: Request) throws -> Response {

        let id: Int = try request.pathParameters.get(.testId)

        return Response(
            status: .ok,
            message: "Test #" + String(id)
        )
    }

}
