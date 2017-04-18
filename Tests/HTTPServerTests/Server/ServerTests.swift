import XCTest
@testable import HTTPServer

extension Server {
    init(host: Axis.Host, responder: Responder) throws {
        self.tcpHost = host
        self.host = "127.0.0.1"
        self.port = 8080
        self.bufferSize = 2048
        self.middleware = []
        self.responder = responder
        self.failure = Server.log(error:)
    }
}

final class ServerStream : Axis.Stream {
    var inputBuffer: Buffer
    var outputBuffer = Buffer()
    var closed = false
    let closeOnFlush: Bool

    init(_ inputBuffer: Buffer = Buffer(), closeOnFlush: Bool = false) {
        self.inputBuffer = inputBuffer
        self.closeOnFlush = closeOnFlush
    }

    public func open(deadline: Double) throws {
        closed = false
    }

    func close() {
        closed = true
    }

    func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Double) throws -> UnsafeBufferPointer<Byte> {
        guard !closed && !inputBuffer.isEmpty else {
            throw StreamError.closedStream
        }
        
        guard !inputBuffer.isEmpty, let readPointer = readBuffer.baseAddress else {
            return UnsafeBufferPointer()
        }
        
        let read = min(readBuffer.count, inputBuffer.count)
        inputBuffer.copyBytes(to: readPointer, count: read)
        inputBuffer = inputBuffer.suffix(from: read)

        if inputBuffer.isEmpty {
            close()
        }
        
        return UnsafeBufferPointer(start: readPointer, count: read)
    }
    
    func write(_ buffer: UnsafeBufferPointer<UInt8>, deadline: Double) throws {
        outputBuffer.append(buffer)
    }
    
    func flush(deadline: Double) throws {
        if closeOnFlush {
            close()
        }
    }
}

class TestHost : Axis.Host {
    let buffer: Buffer
    let closeOnFlush: Bool

    init(buffer: Buffer, closeOnFlush: Bool = false) {
        self.buffer = buffer
        self.closeOnFlush = closeOnFlush
    }

    func accept(deadline: Double) throws -> Axis.Stream {
        return ServerStream(buffer, closeOnFlush: closeOnFlush)
    }
}

enum CustomError : Error {
    case error
}

public class ServerTests : XCTestCase {
    func testServer() throws {
        var called = false

        let responder = BasicResponder { request in
            called = true
            XCTAssertEqual(request.method, .get)
            return Response()
        }

        let server = try Server(
            host: TestHost(buffer: Buffer("GET / HTTP/1.1\r\n\r\n")),
            responder: responder
        )
        let stream = try server.tcpHost.accept(deadline: 1.second.fromNow())
        server.printHeader()
        try server.process(stream: stream)
        XCTAssert(try String(buffer: (stream as! ServerStream).outputBuffer).contains(substring: "OK"))
        XCTAssert(called)
    }

    func testServerRecover() throws {
        var called = false
        var stream: Axis.Stream = ServerStream()

        let responder = BasicResponder { request in
            called = true
            (stream as! ServerStream).closed = false
            XCTAssertEqual(request.method, .get)
            throw HTTPError.badRequest
        }

        let server = try Server(
            host: TestHost(buffer: Buffer("GET / HTTP/1.1\r\n\r\n"), closeOnFlush: true),
            responder: responder
        )
        stream = try server.tcpHost.accept(deadline: 1.second.fromNow())
        try server.process(stream: stream)
        XCTAssert(try String(buffer: (stream as! ServerStream).outputBuffer).contains(substring: "Bad Request"))
        XCTAssert(called)
    }

    func testServerNoRecover() throws {
        var called = false
        var stream: Axis.Stream = ServerStream()

        let responder = BasicResponder { request in
            called = true
            (stream as! ServerStream).closed = false
            XCTAssertEqual(request.method, .get)
            throw CustomError.error
        }

        let server = try Server(
            host: TestHost(buffer: Buffer("GET / HTTP/1.1\r\n\r\n")),
            responder: responder
        )
        stream = try server.tcpHost.accept(deadline: 1.second.fromNow())
        XCTAssertThrowsError(try server.process(stream: stream))
        XCTAssert(try String(buffer: (stream as! ServerStream).outputBuffer).contains(substring: "Internal Server Error"))
        XCTAssert(called)
    }

    func testBrokenPipe() throws {
        var called = false
        var stream: Axis.Stream = ServerStream()

        let responder = BasicResponder { request in
            called = true
            (stream as! ServerStream).closed = false
            XCTAssertEqual(request.method, .get)
            throw SystemError.brokenPipe
        }

        let request = Buffer("GET / HTTP/1.1\r\n\r\n")

        let server = try Server(
            host: TestHost(buffer: request),
            responder: responder
        )
        stream = try server.tcpHost.accept(deadline: 1.second.fromNow())
        try server.process(stream: stream)
        XCTAssert(called)
    }

    func testNotKeepAlive() throws {
        var called = false
        var stream: Axis.Stream = ServerStream()

        let responder = BasicResponder { request in
            called = true
            (stream as! ServerStream).closed = false
            XCTAssertEqual(request.method, .get)
            return Response()
        }

        let request = Buffer("GET / HTTP/1.1\r\nConnection: close\r\n\r\n")

        let server = try Server(
            host: TestHost(buffer: request),
            responder: responder
        )
        stream = try server.tcpHost.accept(deadline: 1.second.fromNow())
        try server.process(stream: stream)
        XCTAssert(try String(buffer: (stream as! ServerStream).outputBuffer).contains(substring: "OK"))
        XCTAssertTrue(stream.closed)
        XCTAssert(called)
    }

    func testUpgradeConnection() throws {
        var called = false
        var upgradeCalled = false
        var stream: Axis.Stream = ServerStream()

        let responder = BasicResponder { request in
            called = true
            (stream as! ServerStream).closed = false
            XCTAssertEqual(request.method, .get)
            var response = Response()
            response.upgradeConnection { request, stream in
                XCTAssertEqual(request.method, .get)
                XCTAssert(try String(buffer: (stream as! ServerStream).outputBuffer).contains(substring: "OK"))
                XCTAssertFalse(stream.closed)
                upgradeCalled = true
            }
            return response
        }

        let request = Buffer("GET / HTTP/1.1\r\nConnection: close\r\n\r\n")

        let server = try Server(
            host: TestHost(buffer: request),
            responder: responder
        )
        stream = try server.tcpHost.accept(deadline: 1.second.fromNow())
        try server.process(stream: stream)
        XCTAssert(try String(buffer: (stream as! ServerStream).outputBuffer).contains(substring: "OK"))
        XCTAssertTrue(stream.closed)
        XCTAssert(called)
        XCTAssert(upgradeCalled)
    }

    func testLogError() {
        Server.log(error: HTTPError.badRequest)
    }
}

extension ServerTests {
    public static var allTests: [(String, (ServerTests) -> () throws -> Void)] {
        return [
            ("testServer", testServer),
            ("testServerRecover", testServerRecover),
            ("testServerNoRecover", testServerNoRecover),
            ("testBrokenPipe", testBrokenPipe),
            ("testNotKeepAlive", testNotKeepAlive),
            ("testUpgradeConnection", testUpgradeConnection),
            ("testLogError", testLogError),
        ]
    }
}
