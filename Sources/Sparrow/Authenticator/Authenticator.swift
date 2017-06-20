import Foundation
import HTTP

public enum AuthenticationError : Error {
    case unauthorizedBasicAuth(realm: String?)
    case unauthorized
    case noAuthorizationHeader
}

extension AuthenticationError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case let .unauthorizedBasicAuth(realm):
            if let realm = realm {
                return Response(
                    status: .unauthorized,
                    headers: ["WWW-Authenticate": "Basic realm=\"\(realm)\""],
                    body: "Unauthorized"
                )
            } else {
                return Response(status: .unauthorized, body: "Unauthorized")
            }
        case .unauthorized:
            return Response(status: .unauthorized, body: "Unauthorized")
        case .noAuthorizationHeader:
            return Response(status: .unauthorized, body: "Authorization header missing.")
        }
    }
}

public struct Authenticator {
    public typealias AuthenticateBasicAuth = (
        _ request: Request,
        _ username: String,
        _ password: String
    ) throws -> Void
    
    public static func basic(
        _ request: Request,
        realm: String? = nil,
        authenticate: AuthenticateBasicAuth
    ) throws {
        let accessDenied = AuthenticationError.unauthorizedBasicAuth(realm: realm)
        
        try custom(request) { request, scheme, payload in
            guard scheme == "Basic" else {
                throw accessDenied
            }
            
            guard
                let decodedData = Data(base64Encoded: payload),
                let decodedCredentials = String(data: decodedData, encoding: .utf8)
                else {
                    throw accessDenied
            }
            
            let credentials = decodedCredentials.components(separatedBy: ":")
            
            guard credentials.count == 2 else {
                throw accessDenied
            }
            
            let username = credentials[0]
            let password = credentials[1]
            
            try authenticate(request, username, password)
        }
    }
    
    public typealias AuthenticateBearer = (_ request: Request, _ payload: String) throws -> Void
    
    public static func bearer(_ request: Request, authenticate: AuthenticateBearer) throws {
        try custom(request) { request, scheme, payload in
            guard scheme == "Bearer" else {
                throw AuthenticationError.unauthorized
            }
            
            try authenticate(request, payload)
        }
    }
    
    public typealias AuthenticateJWT = (_ request: Request, _ jwt: JWT) throws -> Void
    
    public static func jwt(
        _ request: Request,
        algorithm: JWT.Algorithm,
        authenticate: AuthenticateJWT
    ) throws {
        try Authenticator.bearer(request) { request, token in
            let jwt = try JWT(token: token)
            try jwt.verify(using: algorithm)
            try authenticate(request, jwt)
        }
    }
    
    public typealias Authenticate = (
        _ request: Request,
        _ scheme: String,
        _ payload: String
    ) throws -> Void
    
    public static func custom(_ request: Request, authenticate: Authenticate) throws {
        guard let authorization = request.authorization else {
            throw AuthenticationError.noAuthorizationHeader
        }
        
        let tokens = authorization.components(separatedBy: " ")
        
        guard tokens.count == 2 else {
            throw AuthenticationError.unauthorized
        }
        
        do {
            try authenticate(request, tokens[0], tokens[1])
        } catch let error as (Error & ResponseRepresentable) {
            throw error
        } catch {
            throw AuthenticationError.unauthorized
        }
    }
}
