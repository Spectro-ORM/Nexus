import Testing
import HTTPTypes
import Nexus
@testable import NexusRouter

@Suite("Router")
struct RouterTests {

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

    // MARK: - Basic Dispatch

    @Test("test_router_dispatch_matchesGetRoute")
    func test_router_dispatch_matchesGetRoute() async throws {
        let router = Router {
            GET("/health") { conn in
                conn.respond(status: .ok, body: .string("OK"))
            }
        }
        let result = try await router.handle(makeConnection(path: "/health"))
        #expect(result.response.status == .ok)
        #expect(result.isHalted == true)
    }

    @Test("test_router_dispatch_matchesPostRoute")
    func test_router_dispatch_matchesPostRoute() async throws {
        let router = Router {
            POST("/users") { conn in
                conn.respond(status: .created, body: .string("created"))
            }
        }
        let result = try await router.handle(makeConnection(method: .post, path: "/users"))
        #expect(result.response.status == .created)
    }

    @Test("test_router_dispatch_firstMatchWins")
    func test_router_dispatch_firstMatchWins() async throws {
        let router = Router {
            GET("/items") { conn in
                conn.respond(status: .ok, body: .string("first"))
            }
            GET("/items") { conn in
                conn.respond(status: .ok, body: .string("second"))
            }
        }
        let result = try await router.handle(makeConnection(path: "/items"))
        if case .buffered(let data) = result.responseBody {
            #expect(String(data: data, encoding: .utf8) == "first")
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }

    // MARK: - 404 Not Found

    @Test("test_router_noMatch_returns404")
    func test_router_noMatch_returns404() async throws {
        let router = Router {
            GET("/health") { conn in conn.respond(status: .ok) }
        }
        let result = try await router.handle(makeConnection(path: "/missing"))
        #expect(result.response.status == .notFound)
    }

    @Test("test_router_noMatch_haltsConnection")
    func test_router_noMatch_haltsConnection() async throws {
        let router = Router {
            GET("/health") { conn in conn.respond(status: .ok) }
        }
        let result = try await router.handle(makeConnection(path: "/missing"))
        #expect(result.isHalted == true)
    }

    // MARK: - 405 Method Not Allowed

    @Test("test_router_methodMismatch_returns405")
    func test_router_methodMismatch_returns405() async throws {
        let router = Router {
            POST("/users") { conn in conn.respond(status: .created) }
        }
        let result = try await router.handle(makeConnection(method: .get, path: "/users"))
        #expect(result.response.status == .methodNotAllowed)
    }

    @Test("test_router_methodMismatch_haltsConnection")
    func test_router_methodMismatch_haltsConnection() async throws {
        let router = Router {
            POST("/users") { conn in conn.respond(status: .created) }
        }
        let result = try await router.handle(makeConnection(method: .get, path: "/users"))
        #expect(result.isHalted == true)
    }

    // MARK: - Path Parameters

    @Test("test_router_paramRoute_extractsParamToAssigns")
    func test_router_paramRoute_extractsParamToAssigns() async throws {
        let router = Router {
            GET("/users/:id") { conn in
                conn.respond(status: .ok)
            }
        }
        let result = try await router.handle(makeConnection(path: "/users/42"))
        #expect(result.assigns["id"] as? String == "42")
    }

    @Test("test_router_paramRoute_multipleParams")
    func test_router_paramRoute_multipleParams() async throws {
        let router = Router {
            GET("/users/:userId/posts/:postId") { conn in
                conn.respond(status: .ok)
            }
        }
        let result = try await router.handle(
            makeConnection(path: "/users/7/posts/99")
        )
        #expect(result.assigns["userId"] as? String == "7")
        #expect(result.assigns["postId"] as? String == "99")
    }

    // MARK: - DSL Integration

    @Test("test_router_dsl_multipleRoutes")
    func test_router_dsl_multipleRoutes() async throws {
        let router = Router {
            GET("/a") { conn in conn.respond(status: .ok) }
            POST("/b") { conn in conn.respond(status: .created) }
            PUT("/c") { conn in conn.respond(status: .noContent) }
            DELETE("/d") { conn in conn.respond(status: .noContent) }
            PATCH("/e") { conn in conn.respond(status: .ok) }
        }
        let getResult = try await router.handle(makeConnection(method: .get, path: "/a"))
        #expect(getResult.response.status == .ok)

        let postResult = try await router.handle(makeConnection(method: .post, path: "/b"))
        #expect(postResult.response.status == .created)

        let deleteResult = try await router.handle(makeConnection(method: .delete, path: "/d"))
        #expect(deleteResult.response.status == .noContent)
    }

    @Test("test_router_dsl_handlerReceivesConnection")
    func test_router_dsl_handlerReceivesConnection() async throws {
        let router = Router {
            GET("/echo") { conn in
                conn.respond(
                    status: .ok,
                    body: .string(conn.request.path ?? "")
                )
            }
        }
        let result = try await router.handle(makeConnection(path: "/echo"))
        if case .buffered(let data) = result.responseBody {
            #expect(String(data: data, encoding: .utf8) == "/echo")
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }

    // MARK: - Error Propagation

    @Test("test_router_handler_propagatesThrow")
    func test_router_handler_propagatesThrow() async {
        struct TestError: Error {}
        let router = Router {
            GET("/fail") { _ in throw TestError() }
        }
        await #expect(throws: TestError.self) {
            try await router.handle(makeConnection(path: "/fail"))
        }
    }
}
