import Testing
import HTTPTypes
import Nexus
@testable import NexusRouter

@Suite("Scope")
struct ScopeTests {

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

    // MARK: - Basic Scoping

    @Test("test_scope_prefixesRoutes")
    func test_scope_prefixesRoutes() {
        let routes = scope("/api") {
            GET("/users") { conn in conn }
        }
        #expect(routes.count == 1)
        #expect(routes[0].path == "/api/users")
    }

    @Test("test_scope_nestedScopes_compoundsPrefix")
    func test_scope_nestedScopes_compoundsPrefix() {
        let routes = scope("/api") {
            scope("/v2") {
                GET("/users") { conn in conn }
            }
        }
        #expect(routes.count == 1)
        #expect(routes[0].path == "/api/v2/users")
    }

    @Test("test_scope_multipleRoutes_allPrefixed")
    func test_scope_multipleRoutes_allPrefixed() {
        let routes = scope("/api") {
            GET("/users") { conn in conn }
            POST("/users") { conn in conn }
            GET("/health") { conn in conn }
        }
        #expect(routes.count == 3)
        #expect(routes[0].path == "/api/users")
        #expect(routes[1].path == "/api/users")
        #expect(routes[2].path == "/api/health")
    }

    @Test("test_scope_trailingSlashOnPrefix_normalized")
    func test_scope_trailingSlashOnPrefix_normalized() {
        let routes = scope("/api/") {
            GET("/users") { conn in conn }
        }
        #expect(routes[0].path == "/api/users")
    }

    // MARK: - Router Integration

    @Test("test_scope_worksInsideRouterDSL")
    func test_scope_worksInsideRouterDSL() async throws {
        let router = Router {
            GET("/health") { conn in conn.respond(status: .ok) }
            scope("/api") {
                GET("/users") { conn in
                    conn.respond(status: .ok, body: .string("users"))
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/users"))
        #expect(result.response.status == .ok)
    }

    @Test("test_scope_routerDispatch_matchesScopedRoute")
    func test_scope_routerDispatch_matchesScopedRoute() async throws {
        let router = Router {
            scope("/api") {
                GET("/users") { conn in
                    conn.respond(status: .ok, body: .string("scoped"))
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/users"))
        #expect(result.response.status == .ok)
        if case .buffered(let data) = result.responseBody {
            #expect(String(data: data, encoding: .utf8) == "scoped")
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }

    @Test("test_scope_routerDispatch_doesNotMatchUnscopedPath")
    func test_scope_routerDispatch_doesNotMatchUnscopedPath() async throws {
        let router = Router {
            scope("/api") {
                GET("/users") { conn in conn.respond(status: .ok) }
            }
        }
        let result = try await router.handle(makeConnection(path: "/users"))
        #expect(result.response.status == .notFound)
    }

    @Test("test_scope_withParams_paramsStillExtracted")
    func test_scope_withParams_paramsStillExtracted() async throws {
        let router = Router {
            scope("/api") {
                GET("/users/:id") { conn in
                    conn.respond(status: .ok)
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/users/42"))
        #expect(result.params["id"] == "42")
    }
}

// MARK: - Per-Scope Middleware

@Suite("Scope Middleware")
struct ScopeMiddlewareTests {

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

    @Test("test_scope_withMiddleware_middlewareRunsBeforeHandler")
    func test_scope_withMiddleware_middlewareRunsBeforeHandler() async throws {
        let tagMiddleware: Plug = { conn in
            conn.assign(key: "middleware_ran", value: true)
        }
        let router = Router {
            scope("/api", through: [tagMiddleware]) {
                GET("/users") { conn in
                    conn.respond(status: .ok)
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/users"))
        #expect(result.assigns["middleware_ran"] as? Bool == true)
        #expect(result.response.status == .ok)
    }

    @Test("test_scope_withMiddleware_middlewareHalts_handlerSkipped")
    func test_scope_withMiddleware_middlewareHalts_handlerSkipped() async throws {
        let tracker = CallTracker()
        let denyAll: Plug = { conn in
            conn.respond(status: .forbidden, body: .string("Denied"))
        }
        let router = Router {
            scope("/api", through: [denyAll]) {
                GET("/users") { conn in
                    await tracker.markCalled()
                    return conn.respond(status: .ok)
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/users"))
        #expect(result.response.status == .forbidden)
        let wasCalled = await tracker.wasCalled
        #expect(wasCalled == false)
    }

    @Test("test_scope_withMiddleware_multipleMiddleware_runInOrder")
    func test_scope_withMiddleware_multipleMiddleware_runInOrder() async throws {
        let orderTracker = OrderTracker()
        let first: Plug = { conn in await orderTracker.append(1); return conn }
        let second: Plug = { conn in await orderTracker.append(2); return conn }
        let router = Router {
            scope("/api", through: [first, second]) {
                GET("/users") { conn in
                    await orderTracker.append(3)
                    return conn.respond(status: .ok)
                }
            }
        }
        _ = try await router.handle(makeConnection(path: "/api/users"))
        let order = await orderTracker.values
        #expect(order == [1, 2, 3])
    }

    @Test("test_scope_nestedWithMiddleware_outerAndInnerBothApply")
    func test_scope_nestedWithMiddleware_outerAndInnerBothApply() async throws {
        let orderTracker = OrderTracker()
        let outer: Plug = { conn in await orderTracker.append(1); return conn }
        let inner: Plug = { conn in await orderTracker.append(2); return conn }
        let router = Router {
            scope("/api", through: [outer]) {
                scope("/v2", through: [inner]) {
                    GET("/users") { conn in
                        await orderTracker.append(3)
                        return conn.respond(status: .ok)
                    }
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/v2/users"))
        #expect(result.response.status == .ok)
        let order = await orderTracker.values
        #expect(order == [1, 2, 3])
    }

    @Test("test_scope_withEmptyMiddleware_behavesLikePlainScope")
    func test_scope_withEmptyMiddleware_behavesLikePlainScope() async throws {
        let router = Router {
            scope("/api", through: []) {
                GET("/users") { conn in
                    conn.respond(status: .ok, body: .string("ok"))
                }
            }
        }
        let result = try await router.handle(makeConnection(path: "/api/users"))
        #expect(result.response.status == .ok)
    }
}

// MARK: - Helpers

private actor CallTracker {
    private(set) var wasCalled = false
    func markCalled() { wasCalled = true }
}

private actor OrderTracker {
    private(set) var values: [Int] = []
    func append(_ value: Int) { values.append(value) }
}
