import Core
import OpenSSL
import Venice

public struct TCPTLSHost : Host {
    public let host: TCPHost
    public let context: Context

    // TODO: Evaluate
//    public init(configuration: Map) throws {
//        let certificate: String = try configuration.get("certificate")
//        let privateKey: String = try configuration.get("privateKey")
//        let certificateChain = configuration["certificateChain"].string
//
//        self.host = try TCPHost(configuration: configuration)
//        self.context = try Context(
//            certificate: certificate,
//            privateKey: privateKey,
//            certificateChain: certificateChain
//        )
//    }

    public func accept(deadline: Deadline) throws -> Stream {
        let stream = try host.accept(deadline: deadline)
        return try SSLConnection(context: context, rawStream: stream)
    }
}
