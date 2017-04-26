@testable import Sparrow

public class TestCollection: Route {

    public func get(context: RequestContext) throws -> ResponseContext {
        return ResponseContext(
            status: .ok,
            message: "All tests"
        )
    }
}

public class TestEntity: Route {

    public func get(context: RequestContext) throws -> ResponseContext {

        let id: Int = try context.pathParameters.get(.testId)

        return ResponseContext(
            status: .ok,
            message: "Test #" + String(id)
        )
    }

}
