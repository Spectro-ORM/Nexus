import Foundation
import Testing

@testable import Nexus

@Suite("MessageSigning")
struct MessageSigningTests {

    let secret = Data("test-secret-key-for-hmac".utf8)

    @Test func test_sign_producesTokenWithDotSeparator() {
        let token = MessageSigning.sign(payload: Data("hello".utf8), secret: secret)
        let parts = token.split(separator: ".")
        #expect(parts.count == 2)
    }

    @Test func test_verify_validToken_returnsPayload() {
        let payload = Data("hello world".utf8)
        let token = MessageSigning.sign(payload: payload, secret: secret)
        let result = MessageSigning.verify(token: token, secret: secret)
        #expect(result == payload)
    }

    @Test func test_verify_tamperedPayload_returnsNil() {
        let token = MessageSigning.sign(payload: Data("hello".utf8), secret: secret)
        let parts = token.split(separator: ".", maxSplits: 1)
        let tampered = "dGFtcGVyZWQ.\(parts[1])"
        #expect(MessageSigning.verify(token: tampered, secret: secret) == nil)
    }

    @Test func test_verify_tamperedSignature_returnsNil() {
        let token = MessageSigning.sign(payload: Data("hello".utf8), secret: secret)
        let parts = token.split(separator: ".", maxSplits: 1)
        #expect(MessageSigning.verify(token: "\(parts[0]).AAAA", secret: secret) == nil)
    }

    @Test func test_verify_wrongSecret_returnsNil() {
        let token = MessageSigning.sign(payload: Data("hello".utf8), secret: secret)
        let wrongSecret = Data("wrong-secret".utf8)
        #expect(MessageSigning.verify(token: token, secret: wrongSecret) == nil)
    }

    @Test func test_verify_malformedToken_noDot_returnsNil() {
        #expect(MessageSigning.verify(token: "nodothere", secret: secret) == nil)
    }

    @Test func test_verify_malformedToken_empty_returnsNil() {
        #expect(MessageSigning.verify(token: "", secret: secret) == nil)
    }

    @Test func test_sign_emptyPayload_roundtrips() {
        let payload = Data()
        let token = MessageSigning.sign(payload: payload, secret: secret)
        let result = MessageSigning.verify(token: token, secret: secret)
        #expect(result == payload)
    }

    @Test func test_roundtrip_preservesArbitraryPayload() {
        let payload = Data("{\"user_id\":\"42\",\"role\":\"admin\"}".utf8)
        let token = MessageSigning.sign(payload: payload, secret: secret)
        let result = MessageSigning.verify(token: token, secret: secret)
        #expect(result == payload)
    }

    @Test func test_sign_differentPayloads_produceDifferentTokens() {
        let token1 = MessageSigning.sign(payload: Data("payload1".utf8), secret: secret)
        let token2 = MessageSigning.sign(payload: Data("payload2".utf8), secret: secret)
        #expect(token1 != token2)
    }

    @Test func test_sign_differentSecrets_produceDifferentTokens() {
        let payload = Data("same payload".utf8)
        let token1 = MessageSigning.sign(payload: payload, secret: Data("secret1".utf8))
        let token2 = MessageSigning.sign(payload: payload, secret: Data("secret2".utf8))
        #expect(token1 != token2)
    }
}
