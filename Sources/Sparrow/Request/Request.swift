import HTTP
import Core
import Foundation

public class Request {
    public let httpRequest: HTTPRequest
    public var storage: [String: Any] = [:]
    
    var pathComponents: ArraySlice<String>
    
    var parameterMapper: ParameterMapper
    var contentMapper = ContentMapper()
    
    init(httpRequest: HTTPRequest) {
        self.httpRequest = httpRequest
        self.pathComponents = httpRequest.url.pathComponents.dropFirst()
        self.parameterMapper = ParameterMapper(url: httpRequest.url)
    }
}

extension Request {
    func getParameters<P : ParameterMappable>() throws -> P {
        return try P(mapper: parameterMapper)
    }
    
    func getContent<C : ContentMappable>() throws -> C {
        return try C(mapper: contentMapper)
    }
    
    var content: Content {
        return contentMapper.content
    }
}
