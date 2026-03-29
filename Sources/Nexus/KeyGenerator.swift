import Foundation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// PBKDF2-HMAC-SHA256 key derivation.
///
/// Derives a fixed-length cryptographic key from a password and salt.
/// This is the Nexus equivalent of Elixir's `Plug.Crypto.KeyGenerator`.
///
/// Use PBKDF2 when deriving keys from low-entropy human passwords.
/// For high-entropy secrets, prefer HKDF (used by ``MessageEncryption``).
///
/// ```swift
/// let key = KeyGenerator.derive(
///     password: "user-secret",
///     salt: Data("my-app-salt".utf8),
///     iterations: 100_000,
///     keyLength: 32
/// )
/// ```
public enum KeyGenerator {

    /// Derives a key using PBKDF2-HMAC-SHA256.
    ///
    /// The implementation uses pure HMAC-SHA256 per RFC 2898 §5.2,
    /// providing consistent cross-platform behavior on both Apple
    /// platforms (CryptoKit) and Linux (swift-crypto).
    ///
    /// - Parameters:
    ///   - password: The input password string.
    ///   - salt: Random salt bytes. Should be at least 16 bytes.
    ///   - iterations: Number of PBKDF2 iterations. Minimum 1000
    ///     recommended for password-derived keys. Defaults to 100,000.
    ///   - keyLength: Desired output key length in bytes. Defaults to 32.
    /// - Returns: The derived key as `Data`.
    public static func derive(
        password: String,
        salt: Data,
        iterations: Int = 100_000,
        keyLength: Int = 32
    ) -> Data {
        #if DEBUG
        if iterations < 1000 {
            print("[Nexus] Warning: PBKDF2 iterations below 1000 is insecure")
        }
        #endif

        let passwordData = Data(password.utf8)
        let key = SymmetricKey(data: passwordData)
        let hashLength = 32 // SHA-256 output size in bytes
        let blockCount = (keyLength + hashLength - 1) / hashLength

        var derivedKey = Data()
        derivedKey.reserveCapacity(blockCount * hashLength)

        for blockIndex in 1...blockCount {
            // U1 = PRF(Password, Salt || INT_32_BE(i))
            var message = salt
            withUnsafeBytes(of: UInt32(blockIndex).bigEndian) {
                message.append(contentsOf: $0)
            }

            var u = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
            var block = u

            // U2 ... Uc
            for _ in 1..<iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                for i in 0..<block.count {
                    block[i] ^= u[i]
                }
            }

            derivedKey.append(block)
        }

        return Data(derivedKey.prefix(keyLength))
    }
}
