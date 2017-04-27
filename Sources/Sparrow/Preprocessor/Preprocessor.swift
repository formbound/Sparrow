public protocol RequestPreprocessor {
    func preprocess(request: Request) throws
}

public struct BasicRequestPreprocessor: RequestPreprocessor {

    private let handler: (Request) throws -> Void

    internal init(handler: @escaping (Request) throws -> Void) {
        self.handler = handler
    }

    public func preprocess(request: Request) throws {
        return try handler(request)
    }
}

public protocol RequestPostprocessor {
    func postprocess(response: Response) throws
}

public struct BasicRequestPostprocessor: RequestPostprocessor {

    private let handler: (Response) throws -> Void

    internal init(handler: @escaping (Response) throws -> Void) {
        self.handler = handler
    }

    public func postprocess(response: Response) throws {
        return try handler(response)
    }
}


public protocol RequestProcessor: RequestPreprocessor, RequestPostprocessor {}
