public enum RequestContextProcessingResult {
    case `continue`
    case `break`(ResponseContext)
}

public protocol RequestContextPreprocessor {
    func process(requestContext: RequestContext) throws -> RequestContextProcessingResult
}

public struct BasicRequestContextPreprocessor: RequestContextPreprocessor {

    private let handler: (RequestContext) throws -> RequestContextProcessingResult

    internal init(handler: @escaping (RequestContext) throws -> RequestContextProcessingResult) {
        self.handler = handler
    }

    public func process(requestContext: RequestContext) throws -> RequestContextProcessingResult {
        return try handler(requestContext)
    }
}

public protocol ResponseContextPreprocessor {
    func process(responseContext: ResponseContext) throws -> ResponseContext
}

public struct BasicResponseContextPreprocessor: ResponseContextPreprocessor {

    private let handler: (ResponseContext) throws -> ResponseContext

    internal init(handler: @escaping (ResponseContext) throws -> ResponseContext) {
        self.handler = handler
    }

    public func process(responseContext: ResponseContext) throws -> ResponseContext {
        return try handler(responseContext)
    }
}

public protocol ContextPreprocessor: RequestContextPreprocessor, ResponseContextPreprocessor {}
