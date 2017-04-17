import COpenSSL
import Core

public struct SSLHost : Host {
	public let host: Host
	public let context: Context

	public init(host: Host, context: Context) throws {
		self.host = host
		self.context = context
	}

	public func accept(deadline: Deadline) throws -> Stream {
		let rawStream = try host.accept(deadline: deadline)
		let stream = try SSLStream(context: context, rawStream: rawStream)
		try stream.open(deadline: deadline)
		return stream
	}
}
