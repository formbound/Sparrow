public protocol RequestContextPreprocessor {
    func process(requestContext: RequestContext) throws
}

public struct BasicRequestContextPreprocessor: RequestContextPreprocessor {

    private let handler: (RequestContext) throws -> Void

    internal init(handler: @escaping (RequestContext) throws -> Void) {
        self.handler = handler
    }

    public func process(requestContext: RequestContext) throws {
        return try handler(requestContext)
    }
}

public protocol ResponseContextPreprocessor {
    func process(responseContext: ResponseContext) throws
}

public struct BasicResponseContextPreprocessor: ResponseContextPreprocessor {

    private let handler: (ResponseContext) throws -> Void

    internal init(handler: @escaping (ResponseContext) throws -> Void) {
        self.handler = handler
    }

    public func process(responseContext: ResponseContext) throws {
        return try handler(responseContext)
    }
}

public protocol ContextPreprocessor: RequestContextPreprocessor, ResponseContextPreprocessor {}
