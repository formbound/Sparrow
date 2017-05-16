import Venice
import Core
import HTTP

extension Server {
    /// Creates a new HTTP server
    public convenience init(
        bufferSize: Int = 4096,
        parseTimeout: Duration = 5.minutes,
        serializeTimeout: Duration = 5.minutes,
        logAppenders: [LogAppender] = [defaultAppender],
        router: Router
        ) {
        self.init(
            bufferSize: bufferSize,
            parseTimeout: parseTimeout,
            serializeTimeout: serializeTimeout,
            logAppenders: logAppenders,
            respond: router.respond
        )
    }
    
    private static var defaultAppender: LogAppender {
        return StandardOutputAppender(name: "HTTP server", levels: [.error, .info])
    }
}
