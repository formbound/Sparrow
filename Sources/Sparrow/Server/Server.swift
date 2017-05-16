import Venice
import Core
import HTTP

extension Server {
    /// Creates a new HTTP server
    public convenience init(
        parserBufferSize: Int = 4096,
        serializerBufferSize: Int = 4096,
        parseTimeout: Duration = 5.minutes,
        serializeTimeout: Duration = 5.minutes,
        closeConnectionTimeout: Duration = 1.minute,
        logAppenders: [LogAppender] = [defaultAppender],
        router: Router
    ) {
        self.init(
            parserBufferSize: parserBufferSize,
            serializerBufferSize: serializerBufferSize,
            parseTimeout: parseTimeout,
            serializeTimeout: serializeTimeout,
            closeConnectionTimeout: closeConnectionTimeout,
            logAppenders: logAppenders,
            respond: router.respond(to:)
        )
    }
    
    private static var defaultAppender: LogAppender {
        return StandardOutputAppender(name: "HTTP server", levels: [.error, .info])
    }
}
