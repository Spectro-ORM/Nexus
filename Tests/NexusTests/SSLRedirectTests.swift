import Testing
import HTTPTypes
@testable import Nexus

@Suite("SSLRedirect Plug")
struct SSLRedirectTests {

    private func makeConnection(scheme: String = "http", path: String = "/") -> Connection {
        let request = HTTPRequest(method: .get, scheme: scheme, authority: "example.com", path: path)
        return Connection(request: request)
    }

    @Test("test_sslRedirect_httpRequest_redirectsToHttps")
    func test_sslRedirect_httpRequest_redirectsToHttps() async throws {
        let plug = sslRedirect()
        let result = try await plug(makeConnection(scheme: "http", path: "/users"))
        #expect(result.response.status == .movedPermanently)
        let location = result.response.headerFields[HTTPField.Name("Location")!]
        #expect(location == "https://example.com/users")
        #expect(result.isHalted == true)
    }

    @Test("test_sslRedirect_httpsRequest_passesThrough")
    func test_sslRedirect_httpsRequest_passesThrough() async throws {
        let plug = sslRedirect()
        let result = try await plug(makeConnection(scheme: "https"))
        #expect(result.isHalted == false)
    }

    @Test("test_sslRedirect_customHost_usesOverride")
    func test_sslRedirect_customHost_usesOverride() async throws {
        let plug = sslRedirect(host: "api.example.com")
        let result = try await plug(makeConnection(scheme: "http", path: "/health"))
        let location = result.response.headerFields[HTTPField.Name("Location")!]
        #expect(location == "https://api.example.com/health")
    }
}
