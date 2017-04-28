import HTTP
import XCTest

extension Response {
    public func assert(content otherContent: ContentRepresentable) {
        guard case let .content(content) = body else {
            return XCTFail("Invalid body")
        }
        
        XCTAssertEqual(content, otherContent.content)
    }
    
    public func assert(status: HTTPResponse.Status) {
        XCTAssertEqual(self.status, status)
    }
}
