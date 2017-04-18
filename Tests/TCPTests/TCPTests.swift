import XCTest
@testable import TCP
@testable import Core
@testable import Venice

public class TCPTests : XCTestCase {
    func testConnectionRefused() throws {
        let connection = try TCPStream(host: "127.0.0.1", port: 1111, deadline: 1.second.fromNow())
        XCTAssertThrowsError(try connection.open(deadline: 1.second.fromNow()))
    }

    func testWriteClosedSocket() throws {
        let port = 2222

        let channel = try Channel<Void>()

        let coroutine = try Coroutine {
            let host = try TCPHost(host: "0.0.0.0", port: port)
            _ = try host.accept(deadline: 1.second.fromNow())
            try channel.send((), deadline: .never)
        }

        let stream = try TCPStream(host: "127.0.0.1", port: port, deadline: 1.second.fromNow())
        try stream.open(deadline: 1.second.fromNow())
        stream.close()
        try channel.receive(deadline: .never)
        try coroutine.cancel()
        XCTAssertThrowsError(try stream.write([1, 2, 3], deadline: 1.second.fromNow()))
    }

    func testFlushClosedSocket() throws {
        let port = 3333

        let channel = try Channel<Void>()

        let coroutine = try Coroutine {
            let host = try TCPHost(host: "127.0.0.1", port: port)
            _ = try host.accept(deadline: 1.second.fromNow())
            try channel.send((), deadline: .never)
        }

        let connection = try TCPStream(host: "127.0.0.1", port: port, deadline: 1.second.fromNow())
        try connection.open(deadline: 1.second.fromNow())
        connection.close()
        try channel.receive(deadline: .never)
        try coroutine.cancel()
        XCTAssertThrowsError(try connection.flush(deadline: 1.second.fromNow()))
    }

    func testReadClosedSocket() throws {
        let port = 4444

        let channel = try Channel<Void>()

        let coroutine = try Coroutine {
            let host = try TCPHost(host: "127.0.0.1", port: port)
            _ = try host.accept(deadline: 1.second.fromNow())
            try channel.send((), deadline: .never)
        }

        let connection = try TCPStream(host: "127.0.0.1", port: port, deadline: 1.second.fromNow())
        try connection.open(deadline: 1.second.fromNow())
        connection.close()
        try channel.receive(deadline: .never)
        try coroutine.cancel()
        XCTAssertThrowsError(try connection.read(upTo: 1, deadline: 1.second.fromNow()))
    }

    func testWriteRead() throws {
        let port = 5555

        let channel = try Channel<Void>()

        let coroutine = try Coroutine {
            let host = try TCPHost(host: "127.0.0.1", port: port)
            let connection = try host.accept(deadline: 1.second.fromNow())
            let buffer = try connection.read(upTo: 1, deadline: 1.second.fromNow())

            XCTAssertEqual(buffer, Buffer([123]))
            connection.close()
            try channel.send((), deadline: .never)
        }

        let connection = try TCPStream(host: "127.0.0.1", port: port, deadline: 1.second.fromNow())
        try connection.open(deadline: 1.second.fromNow())
        try connection.write([123], deadline: 1.second.fromNow())
        try connection.flush(deadline: 1.second.fromNow())
        try channel.receive(deadline: .never)
        try coroutine.cancel()
    }

    func testClientServer() throws {
        let port = 6666
        let deadline = 5.seconds.fromNow()
        let channel = try Channel<Void>()

        let coroutine = try Coroutine {
            let host = try TCPHost(host: "127.0.0.1", port: port)
            let stream = try host.accept(deadline: deadline)

            try stream.write("ABC", deadline: deadline)
            try stream.flush(deadline: deadline)

            let buffer = try stream.read(upTo: 9, deadline: deadline)
            XCTAssertEqual(buffer.count, 9)
            XCTAssertEqual(buffer, Buffer("123456789"))

            try channel.send((), deadline: .never)
        }

        let stream = try TCPStream(host: "127.0.0.1", port: port, deadline: deadline)
        try stream.open(deadline: deadline)

        let buffer = try stream.read(upTo: 3, deadline: deadline)
        XCTAssertEqual(buffer, Buffer("ABC"))
        XCTAssertEqual(buffer.count, 3)

        try stream.write("123456789", deadline: deadline)
        try stream.flush(deadline: deadline)

        try channel.receive(deadline: .never)
        try coroutine.cancel()
    }
}

extension TCPTests {
    public static var allTests: [(String, (TCPTests) -> () throws -> Void)] {
        return [
            ("testConnectionRefused", testConnectionRefused),
            ("testWriteClosedSocket", testWriteClosedSocket),
            ("testFlushClosedSocket", testFlushClosedSocket),
            ("testReadClosedSocket", testReadClosedSocket),
            ("testWriteRead", testWriteRead),
            ("testClientServer", testClientServer),
        ]
    }
}
