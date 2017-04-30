import struct Foundation.URL
import HTTP
import Core

let server = Server()

try server.start(backlog: 1024) { request in
    return OutgoingResponse(
        version: .oneDotOne,
        status: .ok,
        headers: ["Content-Length": request.headers["Content-Length"] ?? "0"],
        cookieHeaders: []
    ) { stream in
        let body = try request.body.drain(deadline: .never)
        try stream.write(body, deadline: .never)
    }
}
