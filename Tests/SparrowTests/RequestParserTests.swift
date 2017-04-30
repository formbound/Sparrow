import XCTest
import HTTP
import Core

public class RequestParserTests : XCTestCase {
    func testRequestParser() throws {
        do {
            let stream = DataStream(bytes:
                "GET / HTTP/1.1\nContent-Length: 4\r\n\r\nZewo" +
                "POST / HTTP/1.1\nContent-Length: 7\r\n\r\nSparrow" +
                "PUT /you/in/your/place HTTP/1.1\nTransfer-Encoding: chunked\r\n\r\n5\r\nSwift\r\n0\r\n\r\n"
            )
            
            let parser = RequestParser(stream: stream)
            
            try parser.parse(timeout: .never) { request in
                print(request.method, request.url)
                print(request.headers)
                let body = try request.body.drain(deadline: .never)
                try print(String(bytes: body))
            }
        } catch {
            print(error)
        }
    }
}
