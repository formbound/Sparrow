import Core
import HTTP

public struct MessageLogger {
    public let logger: Logger
    public let level: Logger.Level
    
    public init(logger: Logger, level: Logger.Level = .info) {
        self.logger = logger
        self.level = level
    }
    
    public func log(_ response: Response, for request: Request, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        logger.log(
            level: level,
            item:
                "\n" + request.description +
                "\n" + response.description,
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
}
