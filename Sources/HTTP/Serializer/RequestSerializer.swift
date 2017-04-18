import Core
import Venice

public class RequestSerializer {
    let stream: Stream
    let bufferSize: Int

    public init(stream: Stream, bufferSize: Int = 2048) {
        self.stream = stream
        self.bufferSize = bufferSize
    }

    public func serialize(_ request: Request, deadline: Deadline) throws {
        let newLine: [UInt8] = [13, 10]

        try stream.write("\(request.method) \(request.url.absoluteString) HTTP/\(request.version.major).\(request.version.minor)", deadline: deadline)
        try stream.write(newLine, deadline: deadline)

        for (name, value) in request.headers.headers {
            try stream.write("\(name): \(value)", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        }

        try stream.write(newLine, deadline: deadline)

        switch request.body {
        case .data(let bytes):
            try stream.write(bytes, deadline: deadline)
        case .reader(let reader):
            while !reader.closed {
                let bytes = try reader.read(upTo: bufferSize, deadline: deadline)
                guard !bytes.isEmpty else {
                    break
                }

                try stream.write(String(bytes.count, radix: 16), deadline: deadline)
                try stream.write(newLine, deadline: deadline)
                try stream.write(bytes, deadline: deadline)
                try stream.write(newLine, deadline: deadline)
            }

            try stream.write("0", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        case .writer(let writer):
            let body = BodyStream(stream)
            try writer(body)

            try stream.write("0", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        }

        try stream.flush(deadline: deadline)
    }
}
