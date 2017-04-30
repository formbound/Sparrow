import HTTP
import Router
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
