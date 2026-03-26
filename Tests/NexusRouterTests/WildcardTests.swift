import Testing
import HTTPTypes
import Nexus
@testable import NexusRouter

@Suite("Wildcard Paths")
struct WildcardTests {

    // MARK: - PathPattern

    @Test("test_pathPattern_wildcard_matchesAnyRemaining")
    func test_pathPattern_wildcard_matchesAnyRemaining() {
        let pattern = PathPattern("/files/*")
        let result = pattern.match("/files/docs/readme.txt")
        #expect(result != nil)
    }

    @Test("test_pathPattern_wildcard_matchesZeroRemaining")
    func test_pathPattern_wildcard_matchesZeroRemaining() {
        let pattern = PathPattern("/files/*")
        let result = pattern.match("/files/")
        #expect(result != nil)
    }

    @Test("test_pathPattern_namedWildcard_capturesRest")
    func test_pathPattern_namedWildcard_capturesRest() {
        let pattern = PathPattern("/files/*rest")
        let result = pattern.match("/files/docs/readme.txt")
        #expect(result?["rest"] == "docs/readme.txt")
    }

    @Test("test_pathPattern_namedWildcard_capturesEmptyForTrailingSlash")
    func test_pathPattern_namedWildcard_capturesEmptyForTrailingSlash() {
        let pattern = PathPattern("/files/*rest")
        let result = pattern.match("/files/")
        #expect(result?["rest"] == "")
    }

    @Test("test_pathPattern_wildcardWithPrefix_matchesCorrectly")
    func test_pathPattern_wildcardWithPrefix_matchesCorrectly() {
        let pattern = PathPattern("/api/v1/*")
        #expect(pattern.match("/api/v1/users") != nil)
        #expect(pattern.match("/api/v1/users/42") != nil)
        #expect(pattern.match("/api/v2/users") == nil)
    }

    @Test("test_pathPattern_wildcard_doesNotMatchDifferentPrefix")
    func test_pathPattern_wildcard_doesNotMatchDifferentPrefix() {
        let pattern = PathPattern("/files/*")
        #expect(pattern.match("/other/docs") == nil)
    }

    // MARK: - Router Integration

    @Test("test_router_wildcardRoute_matchesSubpaths")
    func test_router_wildcardRoute_matchesSubpaths() async throws {
        let router = Router {
            GET("/files/*path") { conn in
                let path = conn.params["path"] ?? ""
                return conn.respond(status: .ok, body: .string(path))
            }
        }
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/files/docs/readme.txt")
        let conn = Connection(request: request)
        let result = try await router.handle(conn)
        #expect(result.response.status == .ok)
        #expect(result.params["path"] == "docs/readme.txt")
    }
}

@Suite("Forward")
struct ForwardTests {

    private func makeConnection(
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

    @Test("test_forward_delegatesToSubRouter")
    func test_forward_delegatesToSubRouter() async throws {
        let subRouter = Router {
            GET("/users") { conn in
                conn.respond(status: .ok, body: .string("users list"))
            }
        }
        let mainRouter = Router {
            GET("/health") { conn in conn.respond(status: .ok) }
            forward("/api", to: subRouter)
        }
        let result = try await mainRouter.handle(makeConnection(path: "/api/users"))
        #expect(result.response.status == .ok)
        if case .buffered(let data) = result.responseBody {
            #expect(String(data: data, encoding: .utf8) == "users list")
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }

    @Test("test_forward_stripsPrefix")
    func test_forward_stripsPrefix() async throws {
        let subRouter = Router {
            GET("/items/:id") { conn in
                conn.respond(status: .ok)
            }
        }
        let mainRouter = Router {
            forward("/api", to: subRouter)
        }
        let result = try await mainRouter.handle(makeConnection(path: "/api/items/42"))
        #expect(result.response.status == .ok)
        #expect(result.params["id"] == "42")
    }
}
