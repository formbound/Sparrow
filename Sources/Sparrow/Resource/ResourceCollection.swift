import HTTP
import Core

public struct ResourceCollectionResult<T: ContentConvertible>: ContentRepresentable {

    public let elements: [T]
    public let totalElementCount: Int
    public let limit: Int
    public let offset: Int

    public init(elements: [T], totalElementCount: Int, limit: Int, offset: Int) {
        self.elements = elements
        self.totalElementCount = totalElementCount
        self.limit = limit
        self.offset = offset
    }

    public var content: Content {

        return Content(
            dictionary: [
                "objects": Content(array: elements),
                "metadata": Content(
                    dictionary: [
                        "total": totalElementCount,
                        "limit": limit,
                        "offset": offset
                    ])
            ])
    }
}

public protocol ResourceCollection: Resource {
    associatedtype Element: ContentConvertible

    func get(offset: Int, limit: Int?) throws -> ResourceCollectionResult<Element>

    func post(element: Element) throws -> Element

    func delete() throws
}

extension ResourceCollection {

    public func get(context: RequestContext) throws -> ResponseContext {
        return try ResponseContext(
            status: .ok,
            content: get(
                offset: context.queryParameters.value(for: "offset") ?? 0,
                limit: context.queryParameters.value(for: "limit")
            )
        )
    }

    public func post(context: RequestContext) throws -> ResponseContext {
        return try ResponseContext(
            status: .created,
            content: post(element: Element(content: context.content))
        )
    }

    public func delete(context: RequestContext) throws -> ResponseContext {
        try delete()
        return ResponseContext(status: .ok)
    }
}

extension ResourceCollection {

    public func post(element: Element) throws -> Element {
        throw HTTPError(error: .methodNotAllowed)
    }

    func delete() throws {
        throw HTTPError(error: .methodNotAllowed)
    }
}
