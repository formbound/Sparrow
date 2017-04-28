public protocol ContentMappable {
    init(mapper: ContentMapper) throws
}

public final class ContentMapper {
    var content: Content = .null
    
    public init() {}
    
    public func get<C : ContentInitializable>() throws -> C {
        return try C(content: content)
    }
}

// MARK: String

extension String : ContentMappable {
    public init(mapper: ContentMapper) throws {
        self = try mapper.get()
    }
}
