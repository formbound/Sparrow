public protocol RequestPreprocessor {
    func process(request: Request) throws
}

public struct BasicRequestPreprocessor: RequestPreprocessor {

    private let handler: (Request) throws -> Void

    internal init(handler: @escaping (Request) throws -> Void) {
        self.handler = handler
    }

    public func process(request: Request) throws {
        return try handler(request)
    }
}

public protocol ResponsePreprocessor {
    func process(response: Response) throws
}

public struct BasicResponsePreprocessor: ResponsePreprocessor {

    private let handler: (Response) throws -> Void

    internal init(handler: @escaping (Response) throws -> Void) {
        self.handler = handler
    }

    public func process(response: Response) throws {
        return try handler(response)
    }
}

public protocol ContextPreprocessor: RequestPreprocessor, ResponsePreprocessor {}
