import Zewo

public struct MessageLogger {
    public static func log(
        _ response: Response,
        for request: Request,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        column: Int = #column
    ) {
        let locationInfo = Logger.LocationInfo(
            file: file,
            line: line,
            column: column,
            function: function
        )
        
        Logger.info("\n" + request.description + "\n" + response.description, locationInfo: locationInfo)
    }
}
