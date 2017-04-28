import HTTP
import XCTest

extension HTTPResponse {
    public func assert(body: String) {
        do {
            var response = self
            let bytes = try response.body.becomeBytes(deadline: .never)
            try XCTAssertEqual(String(bytes: bytes), body)
        } catch {
            XCTFail("Invalid body")
        }
    }
    
    public func assert(status: Status) {
        XCTAssertEqual(self.status, status)
    }
}
