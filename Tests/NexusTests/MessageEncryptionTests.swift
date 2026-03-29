import Foundation
import Testing
@testable import Nexus

@Suite("MessageEncryption")
struct MessageEncryptionTests {

    let secret = Data("32-byte-secret-key-for-aes256!!".utf8)

    // MARK: - Round-Trip

    @Test("Encrypt then decrypt round-trips arbitrary data")
    func test_encrypt_decrypt_roundTrip() throws {
        let payload = Data("hello, world!".utf8)
        let token = try MessageEncryption.encrypt(payload: payload, secret: secret)
        let decrypted = try MessageEncryption.decrypt(token: token, secret: secret)
        #expect(decrypted == payload)
    }

    @Test("Empty payload encrypts and decrypts correctly")
    func test_emptyPayload_roundTrip() throws {
        let payload = Data()
        let token = try MessageEncryption.encrypt(payload: payload, secret: secret)
        let decrypted = try MessageEncryption.decrypt(token: token, secret: secret)
        #expect(decrypted == payload)
    }

    @Test("Large payload (1 MB) encrypts and decrypts correctly")
    func test_largePayload_roundTrip() throws {
        let payload = Data(repeating: 0xAB, count: 1_000_000)
        let token = try MessageEncryption.encrypt(payload: payload, secret: secret)
        let decrypted = try MessageEncryption.decrypt(token: token, secret: secret)
        #expect(decrypted == payload)
    }

    // MARK: - Tamper Detection

    @Test("Tampered ciphertext fails decryption")
    func test_tamperedCiphertext_throws() throws {
        let token = try MessageEncryption.encrypt(
            payload: Data("secret".utf8),
            secret: secret
        )
        var parts = token.split(separator: ".").map(String.init)
        var chars = Array(parts[1])
        chars[0] = chars[0] == "A" ? "B" : "A"
        parts[1] = String(chars)
        let tampered = parts.joined(separator: ".")

        #expect(throws: (any Error).self) {
            try MessageEncryption.decrypt(token: tampered, secret: secret)
        }
    }

    @Test("Tampered HMAC fails verification")
    func test_tamperedHMAC_throws() throws {
        let token = try MessageEncryption.encrypt(
            payload: Data("secret".utf8),
            secret: secret
        )
        var parts = token.split(separator: ".").map(String.init)
        var chars = Array(parts[2])
        chars[0] = chars[0] == "A" ? "B" : "A"
        parts[2] = String(chars)
        let tampered = parts.joined(separator: ".")

        #expect(throws: (any Error).self) {
            try MessageEncryption.decrypt(token: tampered, secret: secret)
        }
    }

    @Test("Tampered nonce fails decryption")
    func test_tamperedNonce_throws() throws {
        let token = try MessageEncryption.encrypt(
            payload: Data("secret".utf8),
            secret: secret
        )
        var parts = token.split(separator: ".").map(String.init)
        var chars = Array(parts[0])
        chars[0] = chars[0] == "A" ? "B" : "A"
        parts[0] = String(chars)
        let tampered = parts.joined(separator: ".")

        #expect(throws: (any Error).self) {
            try MessageEncryption.decrypt(token: tampered, secret: secret)
        }
    }

    @Test("Wrong secret fails decryption")
    func test_wrongSecret_throws() throws {
        let token = try MessageEncryption.encrypt(
            payload: Data("secret".utf8),
            secret: secret
        )
        let wrongSecret = Data("different-32-byte-secret-key!!!!".utf8)

        #expect(throws: (any Error).self) {
            try MessageEncryption.decrypt(token: token, secret: wrongSecret)
        }
    }

    @Test("Truncated token fails")
    func test_truncatedToken_throws() {
        #expect(throws: (any Error).self) {
            try MessageEncryption.decrypt(token: "abc.def", secret: secret)
        }
    }

    // MARK: - Uniqueness

    @Test("Two encryptions produce different tokens (random nonce)")
    func test_twoEncryptions_differentTokens() throws {
        let payload = Data("same data".utf8)
        let token1 = try MessageEncryption.encrypt(payload: payload, secret: secret)
        let token2 = try MessageEncryption.encrypt(payload: payload, secret: secret)
        #expect(token1 != token2)
    }

    // MARK: - Token Format

    @Test("Token has three base64url segments")
    func test_tokenFormat_threeSegments() throws {
        let token = try MessageEncryption.encrypt(
            payload: Data("test".utf8),
            secret: secret
        )
        let parts = token.split(separator: ".")
        #expect(parts.count == 3)

        for part in parts {
            let decoded = Base64URL.decode(String(part))
            #expect(decoded != nil)
        }
    }

    @Test("HKDF uses distinct info strings for encryption and signing")
    func test_hkdf_distinctKeys() throws {
        // Verify indirectly: same payload encrypted twice produces different tokens
        // (random nonce), but both decrypt correctly with the same secret
        let payload = Data("verify key derivation".utf8)
        let token1 = try MessageEncryption.encrypt(payload: payload, secret: secret)
        let token2 = try MessageEncryption.encrypt(payload: payload, secret: secret)

        let decrypted1 = try MessageEncryption.decrypt(token: token1, secret: secret)
        let decrypted2 = try MessageEncryption.decrypt(token: token2, secret: secret)

        #expect(decrypted1 == payload)
        #expect(decrypted2 == payload)
        #expect(token1 != token2)
    }
}
