@testable import Sparrow

public class TestCollection: Resource {

    public func get(context: RequestContext) throws -> ResponseContext {
        return ResponseContext(
            status: .ok,
            message: "All tests"
        )
    }
}

public class TestEntity: PathParameterResource {

    public func get(context: RequestContext, pathParameter: Int) throws -> ResponseContext {
        return ResponseContext(
            status: .ok,
            message: "Test #" + String(pathParameter)
        )
    }

}
