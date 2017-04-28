import Foundation

public enum AuthenticationResult {
    case accessDenied
    case authenticated
    case payload(key: String, value: Any)
}

public enum AuthenticationError : Error {
    case accessDenied(realm: String?)
}

extension AuthenticationError : ResponseRepresentable {
    public var response: Response {
        switch self {
        case let .accessDenied(realm):
            if let realm = realm {
                return Response(status: .unauthorized, headers: ["WWW-Authenticate": "Basic realm=\"\(realm)\""])
            } else {
                return Response(status: .unauthorized)
            }
        }
    }
}

public struct Authenticator {
    public typealias AuthenticateBasicAuth = (_ username: String, _ password: String) throws -> AuthenticationResult

    func basicAuth(_ request: Request, realm: String?, authenticate: AuthenticateBasicAuth) throws {
        let accessDenied = AuthenticationError.accessDenied(realm: realm)
        
        guard let authorization = request.httpRequest.authorization else {
            throw accessDenied
        }
        
        let tokens = authorization.components(separatedBy: " ")
        
        guard tokens.count == 2 && tokens.first == "Basic" else {
            throw accessDenied
        }
        
        guard
            let decodedData = Data(base64Encoded: tokens[1]),
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
        
        switch try authenticate(username, password) {
        case .accessDenied:
            throw accessDenied
        case .authenticated:
            return
        case .payload(let key, let value):
            request.storage[key] = value
        }
    }
}
