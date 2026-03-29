import Foundation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Errors that can occur during message encryption or decryption.
public enum MessageEncryptionError: Error, Sendable {
    /// The token does not have the expected three-segment format.
    case invalidTokenFormat
    /// The HMAC signature does not match (token was tampered with).
    case hmacVerificationFailed
    /// AES-GCM decryption failed (wrong key or corrupted data).
    case decryptionFailed
}

/// AES-256-GCM encryption with HMAC-SHA256 signing.
///
/// Encrypts a payload so it is both confidential and tamper-proof.
/// This is the Nexus equivalent of Elixir's `Plug.Crypto.MessageEncryptor`.
///
/// The token format is three base64url-encoded segments joined by `.`:
/// ```
/// <nonce>.<ciphertext+tag>.<hmac>
/// ```
///
/// Key derivation uses HKDF with distinct info strings for encryption
/// and signing keys, following cryptographic best practice.
///
/// ```swift
/// let secret = Data("32-byte-secret-key-for-aes256!!".utf8)
/// let token = try MessageEncryption.encrypt(
///     payload: Data("secret".utf8),
///     secret: secret
/// )
/// let payload = try MessageEncryption.decrypt(token: token, secret: secret)
/// // payload == Data("secret".utf8)
/// ```
public enum MessageEncryption {

    /// Encrypts and signs a payload. Returns a base64url-encoded token.
    ///
    /// - Parameters:
    ///   - payload: The raw payload bytes to encrypt.
    ///   - secret: The secret key bytes. Should be at least 32 bytes.
    /// - Returns: A token string in `<nonce>.<ciphertext+tag>.<hmac>` format.
    /// - Throws: ``MessageEncryptionError`` if encryption fails.
    public static func encrypt(payload: Data, secret: Data) throws -> String {
        let inputKey = SymmetricKey(data: secret)
        let encKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: Data("encryption".utf8),
            outputByteCount: 32
        )
        let sigKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: Data("signing".utf8),
            outputByteCount: 32
        )

        let sealedBox = try AES.GCM.seal(payload, using: encKey)
        let nonce = sealedBox.nonce.withUnsafeBytes { Data($0) }
        let ciphertextAndTag = sealedBox.ciphertext + sealedBox.tag

        let hmac = HMAC<SHA256>.authenticationCode(
            for: nonce + ciphertextAndTag,
            using: sigKey
        )

        return [
            Base64URL.encode(nonce),
            Base64URL.encode(ciphertextAndTag),
            Base64URL.encode(Data(hmac)),
        ].joined(separator: ".")
    }

    /// Decrypts and verifies a token. Returns the original payload.
    ///
    /// Verifies the HMAC signature first (fail-fast on tampering), then
    /// decrypts with AES-256-GCM.
    ///
    /// - Parameters:
    ///   - token: The token string in `<nonce>.<ciphertext+tag>.<hmac>` format.
    ///   - secret: The secret key bytes used during encryption.
    /// - Returns: The decrypted payload data.
    /// - Throws: ``MessageEncryptionError`` if the token is invalid, tampered,
    ///   or the key is wrong.
    public static func decrypt(token: String, secret: Data) throws -> Data {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw MessageEncryptionError.invalidTokenFormat
        }

        guard let nonce = Base64URL.decode(String(segments[0])),
              let ciphertextAndTag = Base64URL.decode(String(segments[1])),
              let hmacData = Base64URL.decode(String(segments[2])) else {
            throw MessageEncryptionError.invalidTokenFormat
        }

        let inputKey = SymmetricKey(data: secret)
        let encKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: Data("encryption".utf8),
            outputByteCount: 32
        )
        let sigKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: Data("signing".utf8),
            outputByteCount: 32
        )

        // Verify HMAC first (fail fast on tampering)
        let isValid = HMAC<SHA256>.isValidAuthenticationCode(
            hmacData,
            authenticating: nonce + ciphertextAndTag,
            using: sigKey
        )
        guard isValid else {
            throw MessageEncryptionError.hmacVerificationFailed
        }

        // Decrypt
        do {
            let gcmNonce = try AES.GCM.Nonce(data: nonce)
            let tagSize = 16
            guard ciphertextAndTag.count >= tagSize else {
                throw MessageEncryptionError.decryptionFailed
            }
            let ciphertext = ciphertextAndTag.prefix(ciphertextAndTag.count - tagSize)
            let tag = ciphertextAndTag.suffix(tagSize)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: gcmNonce,
                ciphertext: ciphertext,
                tag: tag
            )
            return try AES.GCM.open(sealedBox, using: encKey)
        } catch {
            throw MessageEncryptionError.decryptionFailed
        }
    }
}
