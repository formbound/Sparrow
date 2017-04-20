import Core


public struct HTTPError: Error {
    public let status: Response.Status
    public var headers: [Header: String]
    public var reason: String

    public init(clientError error: ClientErrorCode, reason: String? = nil, headers: [Header: String] = [:]) {
        self.status = Response.Status(statusCode: error.statusCode)
        self.reason = reason ?? error.statusCode.reasonPhrase
        self.headers = headers
    }

    public init(serverError error: ServerErrorCode, reason: String? = nil, headers: [Header: String] = [:]) {
        self.status = Response.Status(statusCode: error.statusCode)
        self.reason = reason ?? error.statusCode.reasonPhrase
        self.headers = headers
    }
}

public enum ClientErrorCode {
    case badRequest
    case unauthorized
    case paymentRequired
    case forbidden
    case notFound
    case methodNotAllowed
    case notAcceptable
    case proxyAuthenticationRequired
    case requestTimeout
    case conflict
    case gone
    case lengthRequired
    case preconditionFailed
    case requestEntityTooLarge
    case requestURITooLong
    case unsupportedMediaType
    case requestedRangeNotSatisfiable
    case expectationFailed
    case imATeapot
    case authenticationTimeout
    case enhanceYourCalm
    case unprocessableEntity
    case locked
    case failedDependency
    case preconditionRequired
    case tooManyRequests
    case requestHeaderFieldsTooLarge
}

extension ClientErrorCode {
    public var statusCode: Response.Status.Code {
        switch self {
        case .badRequest: return .badRequest
        case .unauthorized: return .unauthorized
        case .paymentRequired: return .paymentRequired
        case .forbidden: return .forbidden
        case .notFound: return .notFound
        case .methodNotAllowed: return .methodNotAllowed
        case .notAcceptable: return .notAcceptable
        case .proxyAuthenticationRequired: return .proxyAuthenticationRequired
        case .requestTimeout: return .requestTimeout
        case .conflict: return .conflict
        case .gone: return .gone
        case .lengthRequired: return .lengthRequired
        case .preconditionFailed: return .preconditionFailed
        case .requestEntityTooLarge: return .requestEntityTooLarge
        case .requestURITooLong: return .requestURITooLong
        case .unsupportedMediaType: return .unsupportedMediaType
        case .requestedRangeNotSatisfiable: return .requestedRangeNotSatisfiable
        case .expectationFailed: return .expectationFailed
        case .imATeapot: return .imATeapot
        case .authenticationTimeout: return .authenticationTimeout
        case .enhanceYourCalm: return .enhanceYourCalm
        case .unprocessableEntity: return .unprocessableEntity
        case .locked: return .locked
        case .failedDependency: return .failedDependency
        case .preconditionRequired: return .preconditionRequired
        case .tooManyRequests: return .tooManyRequests
        case .requestHeaderFieldsTooLarge: return .requestHeaderFieldsTooLarge
        }
    }
}

public enum ServerErrorCode {
    case internalServerError
    case notImplemented
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
    case httpVersionNotSupported
    case variantAlsoNegotiates
    case insufficientStorage
    case loopDetected
    case notExtended
    case networkAuthenticationRequired
}

extension ServerErrorCode {
    public var statusCode: Response.Status.Code {
        switch self {
        case .internalServerError: return .internalServerError
        case .notImplemented: return .notImplemented
        case .badGateway: return .badGateway
        case .serviceUnavailable: return .serviceUnavailable
        case .gatewayTimeout: return .gatewayTimeout
        case .httpVersionNotSupported: return .httpVersionNotSupported
        case .variantAlsoNegotiates: return .variantAlsoNegotiates
        case .insufficientStorage: return .insufficientStorage
        case .loopDetected: return .loopDetected
        case .notExtended: return .notExtended
        case .networkAuthenticationRequired: return .networkAuthenticationRequired
        }
    }
}

