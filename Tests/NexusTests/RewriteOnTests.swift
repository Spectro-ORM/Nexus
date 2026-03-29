import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("RewriteOn Plug")
struct RewriteOnTests {

    // MARK: - Forwarded Proto

    @Test("X-Forwarded-Proto rewrites scheme to https")
    func test_forwardedProto_rewritesScheme() async throws {
        let plug = rewriteOn([.forwardedProto])
        let conn = makeConn(headers: ["X-Forwarded-Proto": "https"])
        let result = try await plug(conn)
        #expect(result.request.scheme == "https")
    }

    // MARK: - Forwarded Host

    @Test("X-Forwarded-Host rewrites authority")
    func test_forwardedHost_rewritesAuthority() async throws {
        let plug = rewriteOn([.forwardedHost])
        let conn = makeConn(headers: ["X-Forwarded-Host": "example.com"])
        let result = try await plug(conn)
        #expect(result.request.authority == "example.com")
    }

    // MARK: - Forwarded For

    @Test("X-Forwarded-For with multiple IPs takes first")
    func test_forwardedFor_multipleIPs_takesFirst() async throws {
        let plug = rewriteOn([.forwardedFor])
        let conn = makeConn(headers: ["X-Forwarded-For": "1.2.3.4, 10.0.0.1"])
        let result = try await plug(conn)
        #expect(result.remoteIP == "1.2.3.4")
    }

    @Test("X-Forwarded-For with single IP")
    func test_forwardedFor_singleIP() async throws {
        let plug = rewriteOn([.forwardedFor])
        let conn = makeConn(headers: ["X-Forwarded-For": "1.2.3.4"])
        let result = try await plug(conn)
        #expect(result.remoteIP == "1.2.3.4")
    }

    // MARK: - Missing Headers

    @Test("Missing header does not rewrite field")
    func test_missingHeader_noRewrite() async throws {
        let plug = rewriteOn([.forwardedProto, .forwardedHost, .forwardedFor])
        let conn = makeConn()
        let result = try await plug(conn)
        #expect(result.request.scheme == "http")
        #expect(result.request.authority == "internal.local")
    }

    // MARK: - Selective Opt-In

    @Test("Only selected headers are processed")
    func test_selectiveOptIn_onlyProto() async throws {
        let plug = rewriteOn([.forwardedProto])
        let conn = makeConn(headers: [
            "X-Forwarded-Proto": "https",
            "X-Forwarded-Host": "public.example.com",
            "X-Forwarded-For": "1.2.3.4",
        ])
        let result = try await plug(conn)
        #expect(result.request.scheme == "https")
        #expect(result.request.authority == "internal.local")
    }

    // MARK: - All Three Together

    @Test("All three headers together rewrite all fields")
    func test_allThree_rewriteAll() async throws {
        let plug = rewriteOn([.forwardedProto, .forwardedHost, .forwardedFor])
        let conn = makeConn(headers: [
            "X-Forwarded-Proto": "https",
            "X-Forwarded-Host": "example.com",
            "X-Forwarded-For": "1.2.3.4",
        ])
        let result = try await plug(conn)
        #expect(result.request.scheme == "https")
        #expect(result.request.authority == "example.com")
        #expect(result.remoteIP == "1.2.3.4")
    }

    // MARK: - Empty Header Value

    @Test("Empty header value does not rewrite")
    func test_emptyHeaderValue_noRewrite() async throws {
        let plug = rewriteOn([.forwardedProto])
        let conn = makeConn(headers: ["X-Forwarded-Proto": ""])
        let result = try await plug(conn)
        #expect(result.request.scheme == "http")
    }

    // MARK: - Remote IP Key Consistency

    @Test("Uses same assign key as Connection.remoteIPKey")
    func test_remoteIP_usesStandardKey() async throws {
        let plug = rewriteOn([.forwardedFor])
        let conn = makeConn(headers: ["X-Forwarded-For": "9.8.7.6"])
        let result = try await plug(conn)
        #expect(result.assigns[Connection.remoteIPKey] as? String == "9.8.7.6")
    }

    // MARK: - Composition

    @Test("Composable with sslRedirect prevents redirect loop")
    func test_composable_withSSLRedirect() async throws {
        let app = pipeline([
            rewriteOn([.forwardedProto]),
            sslRedirect(),
        ])
        let conn = makeConn(headers: ["X-Forwarded-Proto": "https"])
        let result = try await app(conn)
        #expect(result.response.status == .ok)
        #expect(!result.isHalted)
    }
}

// MARK: - Helpers

private func makeConn(
    headers: [String: String] = [:]
) -> Connection {
    var request = HTTPRequest(
        method: .get,
        scheme: "http",
        authority: "internal.local",
        path: "/"
    )
    for (name, value) in headers {
        if let fieldName = HTTPField.Name(name) {
            request.headerFields[fieldName] = value
        }
    }
    return Connection(request: request)
}
