import COpenSSL
import Core

public extension Hash.Function {
	public var digestLength: Int {
		switch self {
		case .md5:
			return Int(MD5_DIGEST_LENGTH)
		case .sha1:
			return Int(SHA_DIGEST_LENGTH)
		case .sha224:
			return Int(SHA224_DIGEST_LENGTH)
		case .sha256:
			return Int(SHA256_DIGEST_LENGTH)
		case .sha384:
			return Int(SHA384_DIGEST_LENGTH)
		case .sha512:
			return Int(SHA512_DIGEST_LENGTH)
		}
	}

	internal var function: ((UnsafePointer<UInt8>?, Int, UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>!) {
		switch self {
		case .md5:
			return { MD5($0!, $1, $2!) }
		case .sha1:
			return { SHA1($0!, $1, $2!) }
		case .sha224:
			return { SHA224($0!, $1, $2!) }
		case .sha256:
			return { SHA256($0!, $1, $2!) }
		case .sha384:
			return { SHA384($0!, $1, $2!) }
		case .sha512:
			return { SHA512($0!, $1, $2!) }
		}
	}

	internal var evp: UnsafePointer<EVP_MD> {
		switch self {
		case .md5:
			return EVP_md5()
		case .sha1:
			return EVP_sha1()
		case .sha224:
			return EVP_sha224()
		case .sha256:
			return EVP_sha256()
		case .sha384:
			return EVP_sha384()
		case .sha512:
			return EVP_sha512()
		}
	}
}

public enum HashError: Error {
    case error(description: String)
}

public struct Hash {
	public enum Function {
		case md5, sha1, sha224, sha256, sha384, sha512
	}

	// MARK: - Hash

	public static func hash(_ function: Function, message: DataRepresentable) throws -> [Byte] {
		initialize()

        let messageBuffer = message.bytes
        return try [Byte](count: function.digestLength) { bytesBuffer in
            _ = messageBuffer.withUnsafeBytes { (messageBytes: UnsafePointer<UInt8>) in
                function.function(messageBytes, messageBuffer.count, bytesBuffer.baseAddress!)
            }
        }
	}

	// MARK: - HMAC

	public static func hmac(_ function: Function, key: DataRepresentable, message: DataRepresentable) throws -> [Byte] {
		initialize()

        let keyBuffer = key.bytes
        let messageBuffer = message.bytes

        return try [Byte](capacity: Int(EVP_MAX_MD_SIZE)) { bytesBuffer in
            return keyBuffer.withUnsafeBytes { (keyBytes: UnsafePointer<UInt8>) -> Int in
                return messageBuffer.withUnsafeBytes { (messageBytes: UnsafePointer<UInt8>) -> Int in
                    var outLength: UInt32 = 0
                    _ = COpenSSL.HMAC(function.evp,
                                  keyBytes,
                                  Int32(keyBuffer.count),
                                  messageBytes,
                                  messageBuffer.count,
                                  bytesBuffer.baseAddress!,
                                  &outLength)
                    return Int(outLength)
                }
            }
        }
	}

    // MARK: - PBKDF2

    public static func pbkdf2(_ function: Function, password: DataRepresentable, salt: DataRepresentable, iterations: Int) throws -> [Byte] {
        initialize()

        let passwordBuffer = password.bytes
        let saltBuffer = salt.bytes

        return try [Byte](count: Int(function.digestLength)) { pointer in
            passwordBuffer.withUnsafeBytes { (passwordBufferPtr: UnsafePointer<Int8>) in
                saltBuffer.withUnsafeBytes { (saltBufferPtr: UnsafePointer<UInt8>) in
                    _ = COpenSSL.PKCS5_PBKDF2_HMAC(passwordBufferPtr,
                                                   Int32(passwordBuffer.count),
                                                   saltBufferPtr,
                                                   Int32(saltBuffer.count),
                                                   Int32(iterations),
                                                   function.evp,
                                                   Int32(pointer.count),
                                                   pointer.baseAddress)
                }
            }
        }
    }

	// MARK: - RSA

	public static func rsa(_ function: Function, key: Key, message: DataRepresentable) throws -> [Byte] {
		initialize()

		let ctx = EVP_MD_CTX_create()
		guard ctx != nil else {
			throw HashError.error(description: lastSSLErrorDescription)
		}

        let messageBuffer = message.bytes

        return try [Byte](capacity: Int(EVP_PKEY_size(key.key))) { bytesBuffer in
            return messageBuffer.withUnsafeBytes { (messageBytes: UnsafePointer<UInt8>) -> Int in
                EVP_DigestInit_ex(ctx, function.evp, nil)
                EVP_DigestUpdate(ctx, UnsafeRawPointer(messageBytes), messageBuffer.count)
                var outLength: UInt32 = 0
                EVP_SignFinal(ctx, bytesBuffer.baseAddress!, &outLength, key.key)
                return Int(outLength)
            }
        }
	}

}
