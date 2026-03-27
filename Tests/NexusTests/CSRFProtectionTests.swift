import Foundation
import HTTPTypes
import Testing

@testable import Nexus

@Suite("CSRFProtection")
struct CSRFProtectionTests {

    let secret = Data("test-secret-key-at-least-32-bytes".utf8)

    private func sessionConfig() -> SessionConfig {
        SessionConfig(secret: secret)
    }

    private func buildConn(
        method: HTTPRequest.Method = .get,
        path: String = "/",
        cookies: String? = nil,
        headers: HTTPFields = [:]
    ) -> Connection {
        var request = HTTPRequest(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path
        )
        request.headerFields = headers
        if let cookies {
            request.headerFields[.cookie] = cookies
        }
        return Connection(request: request)
    }

    /// Runs the session plug then CSRF plug in sequence.
    private func runPipeline(
        _ conn: Connection,
        csrfConfig: CSRFConfig = CSRFConfig()
    ) async throws -> Connection {
        let session = sessionPlug(sessionConfig())
        let csrf = csrfProtection(csrfConfig)
        let pipe = pipeline([session, csrf])
        return try await pipe(conn)
    }

    /// Creates a connection with a session containing a known CSRF token.
    private func connWithCSRFToken(
        _ token: String,
        method: HTTPRequest.Method = .get,
        path: String = "/"
    ) -> Connection {
        let sessionData: [String: String] = ["_csrf_token": token]
        let jsonData = try! JSONEncoder().encode(sessionData)
        let signedCookie = MessageSigning.sign(payload: jsonData, secret: secret)

        return buildConn(
            method: method,
            path: path,
            cookies: "_nexus_session=\(signedCookie)"
        )
    }

    // MARK: - Safe Methods

    @Test func test_csrf_GET_passesThrough() async throws {
        let conn = buildConn(method: .get)
        let result = try await runPipeline(conn)

        #expect(result.isHalted == false)
    }

    @Test func test_csrf_HEAD_passesThrough() async throws {
        let conn = buildConn(method: .head)
        let result = try await runPipeline(conn)

        #expect(result.isHalted == false)
    }

    @Test func test_csrf_OPTIONS_passesThrough() async throws {
        let conn = buildConn(method: .options)
        let result = try await runPipeline(conn)

        #expect(result.isHalted == false)
    }

    // MARK: - State-Changing Methods

    @Test func test_csrf_POST_missingToken_returns403() async throws {
        let conn = connWithCSRFToken("known-token")
        // First do a GET to establish session
        let getResult = try await runPipeline(conn)

        // Extract cookie for POST
        let afterSend = getResult.runBeforeSend()
        let setCookies = afterSend.response.headerFields[values: .setCookie]
        let sessionCookie = setCookies.first(where: { $0.hasPrefix("_nexus_session=") })
        let cookieValue = sessionCookie.flatMap { cookie in
            String(cookie.split(separator: ";")[0].split(separator: "=", maxSplits: 1)[1])
        } ?? ""

        // POST without CSRF token
        let postConn = buildConn(
            method: .post,
            cookies: "_nexus_session=\(cookieValue)"
        )
        let postResult = try await runPipeline(postConn)

        #expect(postResult.response.status == .forbidden)
        #expect(postResult.isHalted == true)
    }

    @Test func test_csrf_POST_wrongToken_returns403() async throws {
        let token = "real-token-value"
        let conn = connWithCSRFToken(token)

        // POST with wrong token in form body
        var postConn = conn
        postConn.request.method = .post
        postConn.requestBody = .buffered(Data("_csrf_token=wrong-token".utf8))
        postConn.request.headerFields[.contentType] = "application/x-www-form-urlencoded"

        let result = try await runPipeline(postConn)

        #expect(result.response.status == .forbidden)
        #expect(result.isHalted == true)
    }

    @Test func test_csrf_POST_validTokenInFormParam_passesThrough() async throws {
        let token = "valid-csrf-token"
        let conn = connWithCSRFToken(token)

        // POST with correct token in form body
        var postConn = conn
        postConn.request.method = .post
        postConn.requestBody = .buffered(Data("_csrf_token=valid-csrf-token".utf8))
        postConn.request.headerFields[.contentType] = "application/x-www-form-urlencoded"

        let result = try await runPipeline(postConn)

        #expect(result.isHalted == false)
    }

    @Test func test_csrf_POST_validTokenInHeader_passesThrough() async throws {
        let token = "valid-csrf-token"
        let conn = connWithCSRFToken(token)

        // POST with correct token in header
        var postConn = conn
        postConn.request.method = .post
        postConn.request.headerFields[HTTPField.Name("x-csrf-token")!] = token

        let result = try await runPipeline(postConn)

        #expect(result.isHalted == false)
    }

    @Test func test_csrf_PUT_validTokenInHeader_passesThrough() async throws {
        let token = "valid-csrf-token"
        let conn = connWithCSRFToken(token)

        var putConn = conn
        putConn.request.method = .put
        putConn.request.headerFields[HTTPField.Name("x-csrf-token")!] = token

        let result = try await runPipeline(putConn)

        #expect(result.isHalted == false)
    }

    @Test func test_csrf_DELETE_validTokenInFormParam_passesThrough() async throws {
        let token = "valid-csrf-token"
        let conn = connWithCSRFToken(token)

        var deleteConn = conn
        deleteConn.request.method = .delete
        deleteConn.requestBody = .buffered(Data("_csrf_token=valid-csrf-token".utf8))
        deleteConn.request.headerFields[.contentType] = "application/x-www-form-urlencoded"

        let result = try await runPipeline(deleteConn)

        #expect(result.isHalted == false)
    }

    // MARK: - Token Generation

    @Test func test_csrf_GET_generatesTokenIfMissing() async throws {
        let conn = buildConn(method: .get)
        let result = try await runPipeline(conn)

        let token = result.getSession("_csrf_token")
        #expect(token != nil)
        #expect(token?.isEmpty == false)
    }

    @Test func test_csrfToken_returnsConsistentToken() async throws {
        let session = sessionPlug(sessionConfig())
        let conn = buildConn()
        let afterSession = try await session(conn)

        let (token1, updated1) = csrfToken(conn: afterSession)
        let (token2, _) = csrfToken(conn: updated1)

        #expect(token1 == token2)
        #expect(!token1.isEmpty)
    }

    @Test func test_csrf_POST_noSession_returns403() async throws {
        // POST with no session at all
        let conn = buildConn(method: .post)
        let result = try await runPipeline(conn)

        #expect(result.response.status == .forbidden)
        #expect(result.isHalted == true)
    }
}
