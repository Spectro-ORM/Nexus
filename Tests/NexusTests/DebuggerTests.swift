import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Debugger Plug")
struct DebuggerTests {

    // MARK: - Error Handling

    @Test("Pipeline error renders HTML debug page with error details")
    func test_error_rendersHTMLPage() async throws {
        let failing: Plug = { _ in
            throw NexusHTTPError(.badRequest, message: "Invalid input")
        }
        let app = debugger(failing)
        let conn = makeConn(path: "/test")
        let result = try await app(conn)

        #expect(result.isHalted)
        #expect(result.response.status == .badRequest)
        let body = bodyString(result)
        #expect(body.contains("NexusHTTPError"))
        #expect(body.contains("Invalid input"))
    }

    @Test("Debug page includes error type and message")
    func test_debugPage_includesErrorTypeAndMessage() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "broken") }
        let app = debugger(failing)
        let result = try await app(makeConn())

        let body = bodyString(result)
        #expect(body.contains("DebugTestError"))
        #expect(body.contains("broken"))
    }

    @Test("Debug page includes request method and path")
    func test_debugPage_includesRequestInfo() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing)
        let conn = makeConn(method: .post, path: "/api/users")
        let result = try await app(conn)

        let body = bodyString(result)
        #expect(body.contains("POST"))
        #expect(body.contains("/api/users"))
    }

    @Test("Debug page includes request headers")
    func test_debugPage_includesHeaders() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing)
        var request = HTTPRequest(
            method: .get, scheme: "https",
            authority: "example.com", path: "/"
        )
        request.headerFields[.accept] = "text/html"
        let conn = Connection(request: request)
        let result = try await app(conn)

        let body = bodyString(result)
        #expect(body.contains("text/html"))
    }

    @Test("Debug page includes query parameters")
    func test_debugPage_includesQueryParams() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing)
        let conn = makeConn(path: "/?name=Alice&age=30")
        let result = try await app(conn)

        let body = bodyString(result)
        #expect(body.contains("name"))
        #expect(body.contains("Alice"))
    }

    @Test("Debug page redacts sensitive assign values")
    func test_debugPage_redactsSensitiveAssigns() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing)
        let conn = makeConn()
            .assign(key: "user_name", value: "Alice")
            .assign(key: "api_secret", value: "s3cr3t")
            .assign(key: "auth_token", value: "tok_123")
            .assign(key: "session_key", value: "key_456")
            .assign(key: "password_hash", value: "hashed")
        let result = try await app(conn)

        let body = bodyString(result)
        #expect(body.contains("Alice"))
        #expect(body.contains("[REDACTED]"))
        #expect(!body.contains("s3cr3t"))
        #expect(!body.contains("tok_123"))
        #expect(!body.contains("key_456"))
        #expect(!body.contains("hashed"))
    }

    // MARK: - Status Code

    @Test("NexusHTTPError uses error's status code")
    func test_nexusHTTPError_usesErrorStatus() async throws {
        let failing: Plug = { _ in
            throw NexusHTTPError(.notFound, message: "Not found")
        }
        let app = debugger(failing)
        let result = try await app(makeConn())
        #expect(result.response.status == .notFound)
    }

    @Test("Non-Nexus error uses status 500")
    func test_genericError_uses500() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing)
        let result = try await app(makeConn())
        #expect(result.response.status == .internalServerError)
    }

    // MARK: - Plain Text Style

    @Test("Plain text style renders text body")
    func test_plainText_rendersTextBody() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing, style: .plainText)
        let conn = makeConn(method: .get, path: "/test")
        let result = try await app(conn)

        #expect(result.response.headerFields[.contentType] == "text/plain; charset=utf-8")
        let body = bodyString(result)
        #expect(body.contains("Nexus Debug"))
        #expect(body.contains("GET"))
        #expect(body.contains("/test"))
    }

    // MARK: - Pass-Through

    @Test("No error in pipeline passes through unchanged")
    func test_noError_passesThrough() async throws {
        let ok: Plug = { conn in
            var copy = conn
            copy.response.status = .ok
            copy.responseBody = .buffered(Data("ok".utf8))
            return copy
        }
        let app = debugger(ok)
        let result = try await app(makeConn())

        #expect(result.response.status == .ok)
        #expect(bodyString(result) == "ok")
    }

    // MARK: - Self-Contained HTML

    @Test("HTML page is self-contained with no external dependencies")
    func test_html_selfContained() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(failing)
        let result = try await app(makeConn())

        let body = bodyString(result)
        #expect(!body.contains("href=\"http"))
        #expect(!body.contains("src=\"http"))
        #expect(body.contains("<style>"))
    }

    // MARK: - Composable

    @Test("Composable wrapping a pipeline with other plugs")
    func test_composable_withPipeline() async throws {
        let failing: Plug = { _ in throw DebugTestError(detail: "") }
        let app = debugger(pipeline([requestId(), failing]))
        let result = try await app(makeConn())

        #expect(result.isHalted)
        #expect(result.response.status == .internalServerError)
    }
}

// MARK: - Helpers

private struct DebugTestError: Error, CustomStringConvertible {
    let detail: String
    var description: String { "DebugTestError: \(detail)" }
}

private func makeConn(
    method: HTTPRequest.Method = .get,
    path: String = "/"
) -> Connection {
    let request = HTTPRequest(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path
    )
    return Connection(request: request)
}

private func bodyString(_ conn: Connection) -> String {
    guard case .buffered(let data) = conn.responseBody else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
}
