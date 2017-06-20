import Crypto
import Foundation

extension JWT {
    public final class HS256Algorithm : Algorithm {
        public let key: String
        
        fileprivate init(key: String) {
            self.key = key
            super.init(name: "HS256")
        }
        
        public override func sign(message: String) throws -> Data {
            return Crypto.hs256(message, key: key)
        }
        
        public override func verify(signature: Data, message: String) throws {
            guard signature == Crypto.hs256(message, key: key) else {
                throw JWTError.invalidSignature
            }
        }
    }
}

extension JWT.Algorithm {
    public static func hs256(key: String) -> JWT.Algorithm {
        return JWT.HS256Algorithm(key: key)
    }
}
