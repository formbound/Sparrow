import Core
import Venice

public struct LoggerPrepocessor: ContextPreprocessor {

    private let debug: Bool
    private let stream: OutputStream?
    private let timeout: Deadline

    public init(debug: Bool = false, stream: OutputStream? = nil, timeout: Deadline = 30.seconds) {
        self.debug = debug
        self.stream = stream
        self.timeout = timeout
    }

    public func process(requestContext: RequestContext) throws -> RequestContextProcessingResult {
        var message: String = ""
        message = "================================================================================\n"
        message += "Request:\n\n"
        message += (debug ? String(describing: requestContext.request.debugDescription) : String(describing: requestContext.request)) + "\n"
        message += "--------------------------------------------------------------------------------\n"

        if let stream = stream {
            try stream.write(message, deadline: timeout.fromNow())
        } else {
            print(message)
        }

        return .continue
    }

    public func process(responseContext: ResponseContext) throws -> ResponseContext {
        var message: String = ""
        message += "Response:\n\n"
        message += (debug ? String(describing: responseContext.debugDescription) : String(describing: responseContext)) + "\n"
        message += "================================================================================\n"

        if let stream = stream {
            try stream.write(message, deadline: timeout.fromNow())
        } else {
            print(message)
        }

        return responseContext
    }
}
