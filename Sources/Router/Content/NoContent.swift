public struct NoContent {
    public static let noContent = NoContent()
}

extension NoContent : ContentMappable {
    public init(mapper: ContentMapper) throws {}
}

extension NoContent : ContentRepresentable {
    public var content: Content {
        return .null
    }
}

extension NoContent : ResponseRepresentable {
    public var response: Response {
        return Response(status: .noContent)
    }
}
