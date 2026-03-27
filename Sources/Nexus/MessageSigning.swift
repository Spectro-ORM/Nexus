import Foundation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// HMAC-SHA256 message signing and verification.
///
/// Provides tamper-proof signing for session cookies and other values
/// that must survive a round-trip through an untrusted client. This is
/// the Nexus equivalent of Elixir's `Plug.Crypto.MessageVerifier`.
///
/// Tokens are **signed**, not encrypted — the payload is visible to
/// anyone who base64-decodes the token. Use encryption when the payload
/// itself must be secret.
///
/// ```swift
/// let secret = Data("my-secret-key".utf8)
/// let token = MessageSigning.sign(payload: Data("hello".utf8), secret: secret)
/// let payload = MessageSigning.verify(token: token, secret: secret)
/// // payload == Data("hello".utf8)
/// ```
public enum MessageSigning {

    /// Signs a payload with HMAC-SHA256 and returns a base64url-encoded token.
    ///
    /// The token format is `<base64url(payload)>.<base64url(hmac)>`.
    ///
    /// - Parameters:
    ///   - payload: The raw payload bytes to sign.
    ///   - secret: The secret key bytes for HMAC-SHA256.
    /// - Returns: A signed token string.
    public static func sign(payload: Data, secret: Data) -> String {
        let key = SymmetricKey(data: secret)
        let encodedPayload = Base64URL.encode(payload)
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(encodedPayload.utf8),
            using: key
        )
        let encodedMAC = Base64URL.encode(Data(mac))
        return "\(encodedPayload).\(encodedMAC)"
    }

    /// Verifies a signed token and returns the original payload if valid.
    ///
    /// Uses constant-time comparison via CryptoKit's
    /// `HMAC.isValidAuthenticationCode` to prevent timing attacks.
    ///
    /// - Parameters:
    ///   - token: The token string in `<base64url(payload)>.<base64url(hmac)>`
    ///     format.
    ///   - secret: The secret key bytes used during signing.
    /// - Returns: The original payload data if the signature is valid, or
    ///   `nil` if the token is malformed or the signature does not match.
    public static func verify(token: String, secret: Data) -> Data? {
        guard let dotIndex = token.firstIndex(of: ".") else { return nil }

        let encodedPayload = String(token[token.startIndex..<dotIndex])
        let macString = String(token[token.index(after: dotIndex)...])
        guard !macString.isEmpty,
              let macData = Base64URL.decode(macString) else {
            return nil
        }

        let key = SymmetricKey(data: secret)
        let isValid = HMAC<SHA256>.isValidAuthenticationCode(
            macData,
            authenticating: Data(encodedPayload.utf8),
            using: key
        )

        guard isValid else { return nil }
        return Base64URL.decode(encodedPayload)
    }
}
