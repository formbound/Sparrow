import Core
import Foundation

public struct HeaderField {
    public let string: String
    
    fileprivate var lowercased: String {
        return string.lowercased()
    }
    
    public init(_ string: String) {
        self.string = string
    }
}

extension HeaderField : Hashable {
    public var hashValue: Int {
        return lowercased.hashValue
    }
    
    public static func == (lhs: HeaderField, rhs: HeaderField) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension HeaderField : ExpressibleByStringLiteral {
    public init(stringLiteral string: String) {
        self.init(string)
    }
    
    public init(extendedGraphemeClusterLiteral string: String){
        self.init(string)
    }
    
    public init(unicodeScalarLiteral string: String){
        self.init(string)
    }
}

extension HeaderField : CustomStringConvertible {
    public var description: String {
        return string
    }
}

public struct Headers {
    public var headers: [HeaderField: String]
    
    public init(_ headers: [HeaderField: String]) {
        self.headers = headers
    }
}

extension Headers {
    public static var empty: Headers {
        return Headers()
    }
}

extension Headers : ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (HeaderField, String)...) {
        var headers: [HeaderField: String] = [:]
        
        for (key, value) in elements {
            headers[key] = value
        }
        
        self.headers = headers
    }
}

extension Headers : Sequence {
    public func makeIterator() -> DictionaryIterator<HeaderField, String> {
        return headers.makeIterator()
    }
    
    public var count: Int {
        return headers.count
    }
    
    public var isEmpty: Bool {
        return headers.isEmpty
    }
    
    public subscript(field: HeaderField) -> String? {
        get {
            return headers[field]
        }
        
        set(header) {
            headers[field] = header
        }
    }
    
    public subscript(field: String) -> String? {
        get {
            return self[HeaderField(field)]
        }
        
        set(header) {
            self[HeaderField(field)] = header
        }
    }
}

extension Headers : CustomStringConvertible {
    public var description: String {
        var string = ""
        
        for (header, value) in headers {
            string += "\(header): \(value)\n"
        }
        
        return string
    }
}

extension Headers : Equatable {}

public func == (lhs: Headers, rhs: Headers) -> Bool {
    return lhs.headers == rhs.headers
}

extension Headers {
    public var contentType: MediaType? {
        get {
            return self["Content-Type"].flatMap({try? MediaType(string: $0)})
        }
        
        set(contentType) {
            self["Content-Type"] = contentType?.description
        }
    }
    
    public var contentLength: Int? {
        get {
            return self["Content-Length"].flatMap({Int($0)})
        }
        
        set(contentLength) {
            self["Content-Length"] = contentLength?.description
        }
    }
    
    public var transferEncoding: String? {
        get {
            return headers["Transfer-Encoding"]
        }
        
        set(transferEncoding) {
            headers["Transfer-Encoding"] = transferEncoding
        }
    }
    
    public var accept: [MediaType] {
        get {
            var acceptedMediaTypes: [MediaType] = []
            
            if let acceptString = self["Accept"] {
                let acceptedTypesString = acceptString.components(separatedBy: ",")
                
                for acceptedTypeString in acceptedTypesString {
                    let acceptedTypeTokens = acceptedTypeString.components(separatedBy: ";")
                    
                    if acceptedTypeTokens.count >= 1 {
                        let mediaTypeString = acceptedTypeTokens[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if let acceptedMediaType = try? MediaType(string: mediaTypeString) {
                            acceptedMediaTypes.append(acceptedMediaType)
                        }
                    }
                }
            }
            
            return acceptedMediaTypes
        }
        
        set(accept) {
            self["Accept"] = accept.map({$0.type + "/" + $0.subtype}).joined(separator: ", ")
        }
    }
}
