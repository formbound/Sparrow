import Core

public protocol ContentNegotiator {
    func serialize(body: Body, mediaType: MediaType) throws -> View

    func serialize(view: View, mediaType: MediaType) throws -> Body
}
