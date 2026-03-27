import Foundation

/// Base64url encoding and decoding (RFC 4648 §5).
///
/// Uses the URL-safe alphabet (`-` and `_` instead of `+` and `/`) and
/// strips padding characters (`=`). Shared by ``MessageSigning`` and
/// CSRF token generation.
enum Base64URL {

    /// Encodes raw bytes into a base64url string without padding.
    ///
    /// - Parameter data: The bytes to encode.
    /// - Returns: A base64url-encoded string.
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes a base64url string back to raw bytes.
    ///
    /// Re-applies standard Base64 padding before decoding.
    ///
    /// - Parameter string: The base64url-encoded string.
    /// - Returns: The decoded bytes, or `nil` if the string is invalid.
    static func decode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Re-apply padding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
