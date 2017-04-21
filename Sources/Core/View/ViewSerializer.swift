import Venice

public enum ViewSerializerError: Error {
    case invalidInput
}

public protocol ViewSerializer {
    init()
    func serialize(_ map: View, bufferSize: Int, body: (UnsafeBufferPointer<Byte>) throws -> Void) throws
    static func serialize(_ map: View, bufferSize: Int) throws -> [Byte]
    static func serialize(_ map: View, stream: OutputStream, bufferSize: Int, deadline: Deadline) throws
}

extension ViewSerializer {
    public static func serialize(_ map: View, bufferSize: Int = 4096) throws -> [Byte] {
        let serializer = self.init()
        var bytes: [Byte] = []

        try serializer.serialize(map, bufferSize: bufferSize) { writeBuffer in
            bytes.append(writeBuffer)
        }

        guard !bytes.isEmpty else {
            throw ViewSerializerError.invalidInput
        }

        return bytes
    }

    public static func serialize(_ map: View, stream: OutputStream, bufferSize: Int = 4096, deadline: Deadline) throws {
        let serializer = self.init()

        try serializer.serialize(map, bufferSize: bufferSize) { buffer in
            try stream.write(buffer, deadline: deadline)
        }
        try stream.flush(deadline: deadline)
    }
}
