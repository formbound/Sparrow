import XCTest

public class Tests : XCTestCase {
    func test() throws {

    }
}

extension Tests {
    public static var allTests: [(String, (Tests) -> () throws -> Void)] {
        return [
            ("test", test),
        ]
    }
}
