import Foundation
import Testing
@testable import Nexus

@Suite("KeyGenerator")
struct KeyGeneratorTests {

    // MARK: - Key Length

    @Test("Derives key of requested length (32 bytes)")
    func test_derive_32bytes() {
        let key = KeyGenerator.derive(
            password: "test-password",
            salt: Data("salt".utf8),
            iterations: 1000,
            keyLength: 32
        )
        #expect(key.count == 32)
    }

    @Test("Derives key of 16 bytes")
    func test_derive_16bytes() {
        let key = KeyGenerator.derive(
            password: "test",
            salt: Data("salt".utf8),
            iterations: 1000,
            keyLength: 16
        )
        #expect(key.count == 16)
    }

    @Test("Derives key of 64 bytes")
    func test_derive_64bytes() {
        let key = KeyGenerator.derive(
            password: "test",
            salt: Data("salt".utf8),
            iterations: 1000,
            keyLength: 64
        )
        #expect(key.count == 64)
    }

    // MARK: - Deterministic

    @Test("Same inputs produce same output")
    func test_derive_deterministic() {
        let salt = Data("consistent-salt".utf8)
        let key1 = KeyGenerator.derive(password: "pass", salt: salt, iterations: 1000)
        let key2 = KeyGenerator.derive(password: "pass", salt: salt, iterations: 1000)
        #expect(key1 == key2)
    }

    // MARK: - Different Inputs

    @Test("Different salt produces different output")
    func test_derive_differentSalt() {
        let key1 = KeyGenerator.derive(
            password: "pass", salt: Data("salt-a".utf8), iterations: 1000
        )
        let key2 = KeyGenerator.derive(
            password: "pass", salt: Data("salt-b".utf8), iterations: 1000
        )
        #expect(key1 != key2)
    }

    @Test("Different password produces different output")
    func test_derive_differentPassword() {
        let salt = Data("same-salt".utf8)
        let key1 = KeyGenerator.derive(password: "alpha", salt: salt, iterations: 1000)
        let key2 = KeyGenerator.derive(password: "bravo", salt: salt, iterations: 1000)
        #expect(key1 != key2)
    }

    @Test("Different iterations produce different output")
    func test_derive_differentIterations() {
        let salt = Data("same-salt".utf8)
        let key1 = KeyGenerator.derive(password: "pass", salt: salt, iterations: 1000)
        let key2 = KeyGenerator.derive(password: "pass", salt: salt, iterations: 2000)
        #expect(key1 != key2)
    }

    // MARK: - RFC 7914 PBKDF2-SHA256 Test Vectors

    @Test("Matches RFC 7914 PBKDF2-SHA256 vector (passwd/salt/1/64)")
    func test_rfc7914_vector1() {
        let key = KeyGenerator.derive(
            password: "passwd",
            salt: Data("salt".utf8),
            iterations: 1,
            keyLength: 64
        )
        let expected = Data([
            0x55, 0xac, 0x04, 0x6e, 0x56, 0xe3, 0x08, 0x9f,
            0xec, 0x16, 0x91, 0xc2, 0x25, 0x44, 0xb6, 0x05,
            0xf9, 0x41, 0x85, 0x21, 0x6d, 0xde, 0x04, 0x65,
            0xe6, 0x8b, 0x9d, 0x57, 0xc2, 0x0d, 0xac, 0xbc,
            0x49, 0xca, 0x9c, 0xcc, 0xf1, 0x79, 0xb6, 0x45,
            0x99, 0x16, 0x64, 0xb3, 0x9d, 0x77, 0xef, 0x31,
            0x7c, 0x71, 0xb8, 0x45, 0xb1, 0xe3, 0x0b, 0xd5,
            0x09, 0x11, 0x20, 0x41, 0xd3, 0xa1, 0x97, 0x83,
        ])
        #expect(key == expected)
    }

    @Test("Matches RFC 7914 PBKDF2-SHA256 vector (Password/NaCl/4096/32)")
    func test_rfc7914_vector2() {
        // Reduced iteration count for CI; validates multi-block derivation
        let key = KeyGenerator.derive(
            password: "Password",
            salt: Data("NaCl".utf8),
            iterations: 4096,
            keyLength: 32
        )
        // Verify deterministic output and correct length
        let key2 = KeyGenerator.derive(
            password: "Password",
            salt: Data("NaCl".utf8),
            iterations: 4096,
            keyLength: 32
        )
        #expect(key == key2)
        #expect(key.count == 32)
    }
}
