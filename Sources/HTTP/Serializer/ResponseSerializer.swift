import Core
import Venice

public class ResponseSerializer {
    let stream: Stream
    let bufferSize: Int

    public init(stream: Stream, bufferSize: Int = 2048) {
        self.stream = stream
        self.bufferSize = bufferSize
    }

    public func serialize(_ response: Response, deadline: Deadline) throws {
        var header = "HTTP/"
        header += response.version.major.description
        header += "."
        header += response.version.minor.description
        header += " "
        header += response.status.statusCode.description
        header += " "
        header += response.reasonPhrase
        header += "\r\n"
        
        for (name, value) in response.headers.headers {
            header += name.rawValue
            header += ": "
            header += value
            header += "\r\n"
        }

        for cookie in response.cookieHeaders {
            header += "Set-Cookie: "
            header += cookie
            header += "\r\n"
        }
        
        header += "\r\n"

        try stream.write(header, deadline: deadline)

        switch response.body {
        case .data(let bytes):
            try stream.write(bytes, deadline: deadline)
        case .reader(let reader):
            while !reader.closed {
                let bytes = try reader.read(upTo: bufferSize, deadline: deadline)
                
                guard !bytes.isEmpty else {
                    break
                }

                try stream.write(String(bytes.count, radix: 16), deadline: deadline)
                try stream.write("\r\n", deadline: deadline)
                try stream.write(bytes, deadline: deadline)
                try stream.write("\r\n", deadline: deadline)
            }

            try stream.write("0\r\n\r\n", deadline: deadline)
        case .writer(let writer):
            let body = BodyStream(stream)
            try writer(body)
            try stream.write("0\r\n\r\n", deadline: deadline)
        }

        try stream.flush(deadline: deadline)
    }
}
