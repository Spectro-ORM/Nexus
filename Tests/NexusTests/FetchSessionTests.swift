import Testing
import Foundation
import HTTPTypes
@testable import Nexus
import NexusTest

@Suite("Fetch Session Helper")
struct FetchSessionTests {

    private let secret = Data("test-secret-key-minimum-32-bytes!!".utf8)

    private var config: SessionConfig {
        SessionConfig(
            secret: secret,
            cookieName: "_test_session",
            secure: false,
            httpOnly: true
        )
    }

    // MARK: - isSessionFetched

    @Test("isSessionFetched is false on fresh connection")
    func test_isSessionFetched_fresh_isFalse() {
        let conn = TestConnection.build(path: "/")
        #expect(!conn.isSessionFetched)
    }

    @Test("isSessionFetched is true after sessionPlug runs")
    func test_isSessionFetched_afterSessionPlug_isTrue() async throws {
        let plug = sessionPlug(config)
        let conn = TestConnection.build(path: "/")
        let result = try await plug(conn)
        #expect(result.isSessionFetched)
    }

    @Test("isSessionFetched is true after fetchSession")
    func test_isSessionFetched_afterFetchSession_isTrue() {
        let conn = TestConnection.build(path: "/")
            .fetchSession(config)
        #expect(conn.isSessionFetched)
    }

    // MARK: - fetchSession with no cookie

    @Test("fetchSession with no cookie gives empty session")
    func test_fetchSession_noCookie_emptySession() {
        let conn = TestConnection.build(path: "/")
            .fetchSession(config)
        #expect(conn.getSession("user_id") == nil)
        #expect(conn.isSessionFetched)
    }

    // MARK: - fetchSession with valid cookie

    @Test("fetchSession with valid signed cookie restores session data")
    func test_fetchSession_validCookie_restoresData() throws {
        // Sign a session payload
        let sessionData = ["user_id": "42", "role": "admin"]
        let jsonData = try JSONEncoder().encode(sessionData)
        let token = MessageSigning.sign(payload: jsonData, secret: secret)

        var headers = HTTPTypes.HTTPFields()
        headers[.cookie] = "_test_session=\(token)"
        let conn = TestConnection.build(path: "/", headers: headers)
            .fetchSession(config)

        #expect(conn.getSession("user_id") == "42")
        #expect(conn.getSession("role") == "admin")
    }

    // MARK: - fetchSession with invalid cookie

    @Test("fetchSession with tampered cookie gives empty session")
    func test_fetchSession_tamperedCookie_emptySession() {
        var headers = HTTPTypes.HTTPFields()
        headers[.cookie] = "_test_session=invalid.token.here"
        let conn = TestConnection.build(path: "/", headers: headers)
            .fetchSession(config)
        #expect(conn.getSession("user_id") == nil)
        #expect(conn.isSessionFetched)
    }

    // MARK: - fetchSessionIfMissing

    @Test("fetchSessionIfMissing fetches when not already fetched")
    func test_fetchSessionIfMissing_notFetched_fetchesSession() {
        let conn = TestConnection.build(path: "/")
            .fetchSessionIfMissing(config)
        #expect(conn.isSessionFetched)
    }

    @Test("fetchSessionIfMissing is no-op when already fetched")
    func test_fetchSessionIfMissing_alreadyFetched_noOp() {
        let conn = TestConnection.build(path: "/")
            .fetchSession(config)
            .putSession(key: "marker", value: "original")
            .fetchSessionIfMissing(config)
        // The second fetchSessionIfMissing should NOT clear the data we put
        #expect(conn.getSession("marker") == "original")
    }

    // MARK: - clearSession compatibility

    @Test("clearSession works after fetchSession")
    func test_clearSession_afterFetchSession_clearsData() {
        let conn = TestConnection.build(path: "/")
            .fetchSession(config)
            .putSession(key: "user_id", value: "99")
            .clearSession()
        #expect(conn.getSession("user_id") == nil)
        // isSessionFetched still true (assigns key still present, just empty)
        #expect(conn.isSessionFetched)
    }
}
