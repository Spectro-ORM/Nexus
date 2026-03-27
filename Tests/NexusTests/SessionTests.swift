import Foundation
import HTTPTypes
import Testing

@testable import Nexus

@Suite("Session")
struct SessionTests {

    let secret = Data("test-secret-key-at-least-32-bytes".utf8)

    private func config(
        cookieName: String = "_nexus_session"
    ) -> SessionConfig {
        SessionConfig(secret: secret, cookieName: cookieName)
    }

    private func buildConn(
        method: HTTPRequest.Method = .get,
        path: String = "/",
        cookies: String? = nil
    ) -> Connection {
        var request = HTTPRequest(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path
        )
        if let cookies {
            request.headerFields[.cookie] = cookies
        }
        return Connection(request: request)
    }

    /// Creates a valid signed session cookie value.
    private func signedSession(_ data: [String: String]) -> String {
        let jsonData = try! JSONEncoder().encode(data)
        return MessageSigning.sign(payload: jsonData, secret: secret)
    }

    // MARK: - Session Plug Read Phase

    @Test func test_sessionPlug_noExistingCookie_createsEmptySession() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        let result = try await plug(conn)

        let session = result.assigns[Connection.sessionKey] as? [String: String]
        #expect(session == [:])
    }

    @Test func test_sessionPlug_validCookie_restoresSession() async throws {
        let token = signedSession(["user_id": "42"])
        let plug = sessionPlug(config())
        let conn = buildConn(cookies: "_nexus_session=\(token)")
        let result = try await plug(conn)

        #expect(result.getSession("user_id") == "42")
    }

    @Test func test_sessionPlug_invalidSignature_createsEmptySession() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn(cookies: "_nexus_session=tampered.garbage")
        let result = try await plug(conn)

        let session = result.assigns[Connection.sessionKey] as? [String: String]
        #expect(session == [:])
    }

    @Test func test_sessionPlug_tamperedCookie_createsEmptySession() async throws {
        let token = signedSession(["user_id": "42"])
        let parts = token.split(separator: ".", maxSplits: 1)
        let tampered = "dGFtcGVyZWQ.\(parts[1])"

        let plug = sessionPlug(config())
        let conn = buildConn(cookies: "_nexus_session=\(tampered)")
        let result = try await plug(conn)

        let session = result.assigns[Connection.sessionKey] as? [String: String]
        #expect(session == [:])
    }

    // MARK: - Session Helpers

    @Test func test_putSession_writesValue() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        let result = try await plug(conn)

        let updated = result.putSession(key: "role", value: "admin")
        #expect(updated.getSession("role") == "admin")
    }

    @Test func test_getSession_missingKey_returnsNil() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        let result = try await plug(conn)

        #expect(result.getSession("nonexistent") == nil)
    }

    @Test func test_deleteSession_removesSingleKey() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        var result = try await plug(conn)

        result = result
            .putSession(key: "a", value: "1")
            .putSession(key: "b", value: "2")
            .deleteSession("a")

        #expect(result.getSession("a") == nil)
        #expect(result.getSession("b") == "2")
    }

    @Test func test_clearSession_removesAllData() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        var result = try await plug(conn)

        result = result
            .putSession(key: "a", value: "1")
            .putSession(key: "b", value: "2")
            .clearSession()

        #expect(result.getSession("a") == nil)
        #expect(result.getSession("b") == nil)
    }

    @Test func test_clearSession_marksForDeletion() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        var result = try await plug(conn)

        result = result.clearSession()
        let shouldDrop = result.assigns[Connection.sessionDropKey] as? Bool
        #expect(shouldDrop == true)
    }

    // MARK: - BeforeSend Cookie Writing

    @Test func test_sessionPlug_beforeSend_setsCookieWhenTouched() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        var result = try await plug(conn)

        result = result.putSession(key: "user_id", value: "42")
        result = result.runBeforeSend()

        // Check that a Set-Cookie header was written
        let setCookies = result.response.headerFields[values: .setCookie]
        #expect(setCookies.contains(where: { $0.hasPrefix("_nexus_session=") }))
    }

    @Test func test_sessionPlug_beforeSend_untouchedSession_noCookieWritten() async throws {
        let plug = sessionPlug(config())
        let conn = buildConn()
        let result = try await plug(conn)

        let afterSend = result.runBeforeSend()
        let setCookies = afterSend.response.headerFields[values: .setCookie]
        #expect(!setCookies.contains(where: { $0.hasPrefix("_nexus_session=") }))
    }

    @Test func test_sessionPlug_beforeSend_clearSessionDeletesCookie() async throws {
        let token = signedSession(["user_id": "42"])
        let plug = sessionPlug(config())
        let conn = buildConn(cookies: "_nexus_session=\(token)")
        var result = try await plug(conn)

        result = result.clearSession()
        result = result.runBeforeSend()

        let setCookies = result.response.headerFields[values: .setCookie]
        #expect(setCookies.contains(where: { $0.contains("Max-Age=0") }))
    }

    @Test func test_sessionPlug_cookieAttributes_matchConfig() async throws {
        let cfg = SessionConfig(
            secret: secret,
            cookieName: "_my_app",
            path: "/app",
            domain: "example.com",
            maxAge: 3600,
            secure: true,
            httpOnly: true,
            sameSite: .strict
        )
        let plug = sessionPlug(cfg)
        let conn = buildConn()
        var result = try await plug(conn)

        result = result.putSession(key: "x", value: "y")
        result = result.runBeforeSend()

        let setCookies = result.response.headerFields[values: .setCookie]
        let sessionCookie = setCookies.first(where: { $0.hasPrefix("_my_app=") })
        #expect(sessionCookie != nil)
        #expect(sessionCookie?.contains("Path=/app") == true)
        #expect(sessionCookie?.contains("Domain=example.com") == true)
        #expect(sessionCookie?.contains("Max-Age=3600") == true)
        #expect(sessionCookie?.contains("Secure") == true)
        #expect(sessionCookie?.contains("HttpOnly") == true)
        #expect(sessionCookie?.contains("SameSite=Strict") == true)
    }

    @Test func test_sessionPlug_roundtrip_preservesData() async throws {
        let plug = sessionPlug(config())

        // First request: write session
        let conn1 = buildConn()
        var result1 = try await plug(conn1)
        result1 = result1.putSession(key: "user_id", value: "42")
        result1 = result1.runBeforeSend()

        // Extract the cookie value
        let setCookies = result1.response.headerFields[values: .setCookie]
        let sessionCookie = setCookies.first(where: { $0.hasPrefix("_nexus_session=") })
        let cookieValue = sessionCookie?
            .split(separator: ";")[0]
            .split(separator: "=", maxSplits: 1)[1]
        let tokenStr = String(cookieValue ?? "")

        // Second request: read session back
        let conn2 = buildConn(cookies: "_nexus_session=\(tokenStr)")
        let result2 = try await plug(conn2)

        #expect(result2.getSession("user_id") == "42")
    }
}
