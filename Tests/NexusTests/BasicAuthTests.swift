import Testing
import Foundation
import HTTPTypes
@testable import Nexus

@Suite("BasicAuth Plug")
struct BasicAuthTests {

    private func makeConnection(authorization: String? = nil) -> Connection {
        var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        if let auth = authorization {
            request.headerFields[.authorization] = auth
        }
        return Connection(request: request)
    }

    private func encode(_ user: String, _ pass: String) -> String {
        let data = Data("\(user):\(pass)".utf8)
        return "Basic \(data.base64EncodedString())"
    }

    @Test("test_basicAuth_validCredentials_passesThrough")
    func test_basicAuth_validCredentials_passesThrough() async throws {
        let auth = basicAuth { user, pass in user == "admin" && pass == "secret" }
        let conn = makeConnection(authorization: encode("admin", "secret"))
        let result = try await auth(conn)
        #expect(result.isHalted == false)
        #expect(result.assigns["basic_auth_username"] as? String == "admin")
    }

    @Test("test_basicAuth_invalidCredentials_returns401")
    func test_basicAuth_invalidCredentials_returns401() async throws {
        let auth = basicAuth { user, pass in user == "admin" && pass == "secret" }
        let conn = makeConnection(authorization: encode("admin", "wrong"))
        let result = try await auth(conn)
        #expect(result.response.status == .unauthorized)
        #expect(result.isHalted == true)
    }

    @Test("test_basicAuth_missingHeader_returns401")
    func test_basicAuth_missingHeader_returns401() async throws {
        let auth = basicAuth { _, _ in true }
        let conn = makeConnection()
        let result = try await auth(conn)
        #expect(result.response.status == .unauthorized)
    }

    @Test("test_basicAuth_malformedHeader_returns401")
    func test_basicAuth_malformedHeader_returns401() async throws {
        let auth = basicAuth { _, _ in true }
        let conn = makeConnection(authorization: "Bearer token123")
        let result = try await auth(conn)
        #expect(result.response.status == .unauthorized)
    }

    @Test("test_basicAuth_setsWWWAuthenticateHeader")
    func test_basicAuth_setsWWWAuthenticateHeader() async throws {
        let auth = basicAuth(realm: "DonutShop") { _, _ in false }
        let conn = makeConnection(authorization: encode("user", "pass"))
        let result = try await auth(conn)
        let header = result.response.headerFields[HTTPField.Name("WWW-Authenticate")!]
        #expect(header == "Basic realm=\"DonutShop\"")
    }
}
