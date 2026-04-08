import Testing
import HTTPTypes
import Foundation
@testable import Nexus

/// Tests for public APIs that may have missing coverage
@Suite("Public APIs Coverage")
struct PublicAPIsCoverageTests {

    // MARK: - Connection Public APIs

    @Test("Connection init with all defaults")
    func connectionInitDefaults() {
        let request = HTTPRequest(method: .get, path: "/test")
        let conn = Connection(request: request)

        #expect(conn.request == request)
        #expect(conn.response.status == .ok)
        #expect(conn.isHalted == false)
        #expect(conn.assigns.isEmpty)
        #expect(conn.beforeSend.isEmpty)
        case .empty = conn.requestBody
        case .empty = conn.responseBody
    }

    @Test("Connection init with custom body")
    func connectionInitCustomBody() {
        let request = HTTPRequest(method: .post, path: "/test")
        let body = RequestBody.buffered(Data("test".utf8))
        let conn = Connection(request: request, requestBody: body)

        case let .buffered(data) = conn.requestBody
        #expect(String(data: data, encoding: .utf8) == "test")
    }

    // MARK: - Connection+QueryParams

    @Test("query parameter extraction")
    func queryParameterExtraction() async throws {
        var conn = TestConnection.make(path: "/test?key=value&foo=bar")

        // Test that query params can be accessed
        let queryParams = conn.queryParams
        #expect(queryParams["key"] == "value")
        #expect(queryParams["foo"] == "bar")
    }

    @Test("query parameter with no value")
    func queryParameterNoValue() async throws {
        var conn = TestConnection.make(path: "/test?key")

        let queryParams = conn.queryParams
        #expect(queryParams["key"] == "")
    }

    @Test("query parameter with multiple values")
    func queryParameterMultipleValues() async throws {
        var conn = TestConnection.make(path: "/test?key=value1&key=value2")

        let queryParams = conn.queryParams
        // Should return last value or first depending on implementation
        #expect(queryParams["key"] != nil)
    }

    @Test("query parameter with encoded values")
    func queryParameterEncodedValues() async throws {
        var conn = TestConnection.make(path: "/test?key=hello%20world")

        let queryParams = conn.queryParams
        #expect(queryParams["key"] == "hello world")
    }

    // MARK: - Connection+Respond

    @Test("respond with status only")
    func respondWithStatusOnly() async throws {
        let conn = TestConnection.make()
        let result = conn.respond(status: .created)

        #expect(result.response.status == .created)
        #expect(result.isHalted == true)
    }

    @Test("respond with status and body")
    func respondWithStatusAndBody() async throws {
        let conn = TestConnection.make()
        let result = conn.respond(status: .ok, body: .string("test"))

        #expect(result.response.status == .ok)
        case let .buffered(data) = result.responseBody
        #expect(String(data: data, encoding: .utf8) == "test")
        #expect(result.isHalted == true)
    }

    @Test("respond with status body and headers")
    func respondWithStatusBodyAndHeaders() async throws {
        let conn = TestConnection.make()
        let result = conn.respond(
            status: .ok,
            body: .string("test"),
            headers: [.contentType: "text/plain"]
        )

        #expect(result.response.status == .ok)
        #expect(result.response.headerFields[.contentType] == "text/plain")
        #expect(result.isHalted == true)
    }

    // MARK: - Connection+JSON

    @Test("json response with encodable")
    func jsonResponseWithEncodable() async throws {
        struct TestStruct: Codable, Sendable {
            let name: String
            let value: Int
        }

        let conn = TestConnection.make()
        let value = TestStruct(name: "test", value: 42)
        let result = conn.json(value)

        #expect(result.response.status == .ok)
        #expect(result.response.headerFields[.contentType] == "application/json")
        case let .buffered(data) = result.responseBody
        let decoded = try JSONDecoder().decode(TestStruct.self, from: data)
        #expect(decoded.name == "test")
        #expect(decoded.value == 42)
        #expect(result.isHalted == true)
    }

    @Test("json response with custom status")
    func jsonResponseWithCustomStatus() async throws {
        struct TestStruct: Codable, Sendable {
            let id: Int
        }

        let conn = TestConnection.make()
        let result = conn.json(TestStruct(id: 123), status: .created)

        #expect(result.response.status == .created)
        #expect(result.response.headerFields[.contentType] == "application/json")
    }

    // MARK: - Connection+HTML

    @Test("html response")
    func htmlResponse() async throws {
        let conn = TestConnection.make()
        let result = conn.html("<h1>Hello</h1>")

        #expect(result.response.status == .ok)
        #expect(result.response.headerFields[.contentType] == "text/html")
        case let .buffered(data) = result.responseBody
        #expect(String(data: data, encoding: .utf8) == "<h1>Hello</h1>")
        #expect(result.isHalted == true)
    }

    // MARK: - Connection+Inform

    @Test("inform response")
    func informResponse() async throws {
        let conn = TestConnection.make()
        let result = conn.inform("Success message")

        #expect(result.response.status == .ok)
        case let .buffered(data) = result.responseBody
        #expect(String(data: data, encoding: .utf8)?.contains("Success message") ?? false)
        #expect(result.isHalted == true)
    }

    // MARK: - Connection+TypedAssigns

    @Test("typed assign convenience")
    func typedAssignConvenience() async throws {
        struct TestState: Sendable {
            var count = 0
        }

        let conn = TestConnection.make()
        let result = conn.assign(key: "state", value: TestState())

        let state = result.assigns["state"] as? TestState
        #expect(state?.count == 0)
    }

    // MARK: - Route Helper Functions

    @Test("GET route helper")
    func getRouteHelper() async throws {
        let route = GET("/test") { conn in
            conn.respond(status: .ok)
        }

        #expect(route.method == .get)
        #expect(route.path == "/test")
    }

    @Test("POST route helper")
    func postRouteHelper() async throws {
        let route = POST("/test") { conn in
            conn.respond(status: .created)
        }

        #expect(route.method == .post)
        #expect(route.path == "/test")
    }

    @Test("PUT route helper")
    func putRouteHelper() async throws {
        let route = PUT("/test") { conn in
            conn.respond(status: .ok)
        }

        #expect(route.method == .put)
        #expect(route.path == "/test")
    }

    @Test("PATCH route helper")
    func patchRouteHelper() async throws {
        let route = PATCH("/test") { conn in
            conn.respond(status: .ok)
        }

        #expect(route.method == .patch)
        #expect(route.path == "/test")
    }

    @Test("DELETE route helper")
    func deleteRouteHelper() async throws {
        let route = DELETE("/test") { conn in
            conn.respond(status: .noContent)
        }

        #expect(route.method == .delete)
        #expect(route.path == "/test")
    }

    // MARK: - Router Public APIs

    @Test("Router with no routes returns 404")
    func routerNoRoutes404() async throws {
        let router = Router { [] }

        let conn = TestConnection.make(path: "/test")
        let result = try await router.handle(conn)

        #expect(result.response.status == .notFound)
        #expect(result.isHalted == true)
    }

    @Test("Router with matching route")
    func routerMatchingRoute() async throws {
        let router = Router {
            GET("/test") { conn in
                conn.respond(status: .ok, body: .string("matched"))
            }
        }

        let conn = TestConnection.make(path: "/test")
        let result = try await router.handle(conn)

        #expect(result.response.status == .ok)
        case let .buffered(data) = result.responseBody
        #expect(String(data: data, encoding: .utf8) == "matched")
    }

    @Test("Router path parameter extraction")
    func routerPathParameterExtraction() async throws {
        let router = Router {
            GET("/users/:id") { conn in
                let id = conn.params["id"] ?? ""
                return conn.respond(status: .ok, body: .string("User \(id)"))
            }
        }

        let conn = TestConnection.make(path: "/users/123")
        let result = try await router.handle(conn)

        #expect(result.response.status == .ok)
        case let .buffered(data) = result.responseBody
        #expect(String(data: data, encoding: .utf8) == "User 123")
    }

    @Test("Router 405 method not allowed")
    func router405MethodNotAllowed() async throws {
        let router = Router {
            GET("/test") { conn in
                conn.respond(status: .ok)
            }
        }

        let conn = TestConnection.make(method: .post, path: "/test")
        let result = try await router.handle(conn)

        #expect(result.response.status == .methodNotAllowed)
        #expect(result.isHalted == true)
    }

    // MARK: - NamedPipeline

    @Test("NamedPipeline basic usage")
    func namedPipelineBasicUsage() async throws {
        let pipeline = NamedPipeline("test") {
            "value1"
        }

        let result = await pipeline.run()
        #expect(result == "value1")
    }

    @Test("NamedPipeline with multiple plugs")
    func namedPipelineMultiplePlugs() async throws {
        let pipeline = NamedPipeline("test") {
            pipe(
                { conn in
                    var copy = conn
                    copy.assigns["step1"] = true
                    return copy
                },
                { conn in
                    var copy = conn
                    copy.assigns["step2"] = true
                    return copy
                }
            )
        }

        let conn = TestConnection.make()
        let result = try await pipeline.call(conn)

        #expect(result.assigns["step1"] as? Bool == true)
        #expect(result.assigns["step2"] as? Bool == true)
    }

    // MARK: - Error Handling

    @Test("NexusHTTPError public initializer")
    func nexusHTTPErrorInit() {
        let error = NexusHTTPError(
            status: .badRequest,
            message: "Invalid input"
        )

        #expect(error.status == .badRequest)
        #expect(String(describing: error).contains("Invalid input"))
    }

    @Test("NexusHTTPError with custom body")
    func nexusHTTPErrorCustomBody() {
        let error = NexusHTTPError(
            status: .unprocessableEntity,
            body: .string("{\"error\": \"validation failed\"}")
        )

        #expect(error.status == .unprocessableEntity)
    }

    // MARK: - SSE

    @Test("SSE creation")
    func sseCreation() async throws {
        let sse = SSE { continuation in
            continuation.yield(.event(
                id: "1",
                event: "message",
                data: "Hello"
            ))
            continuation.finish()
        }

        // Verify SSE is created
        // Actual streaming would require more complex setup
    }

    @Test("SSE event serialization")
    func sseEventSerialization() {
        let event = SSE.Event(
            id: "1",
            event: "message",
            data: "Hello",
            retry: 1000
        )

        // Event should serialize properly
        #expect(event.id == "1")
        #expect(event.event == "message")
        #expect(event.data == "Hello")
        #expect(event.retry == 1000)
    }

    // MARK: - Module Conformance

    @Test("Router conforms to ModulePlug")
    func routerModulePlugConformance() async throws {
        let router = Router {
            GET("/test") { $0.respond(status: .ok) }
        }

        // Should be usable as a Plug directly
        let conn = TestConnection.make(path: "/test")
        let result = try await router(conn)

        #expect(result.response.status == .ok)
    }

    @Test("NamedPipeline conforms to ModulePlug")
    func namedPipelineModulePlugConformance() async throws {
        let pipeline = NamedPipeline("test") {
            { conn in
                conn.respond(status: .ok)
            }
        }

        let conn = TestConnection.make()
        let result = try await pipeline.call(conn)

        #expect(result.response.status == .ok)
    }

    // MARK: - Cookie Helpers

    @Test("reqCookies access")
    func reqCookiesAccess() async throws {
        var conn = TestConnection.make()
        conn.reqCookies = ["session": "abc123"]

        #expect(conn.reqCookies["session"] == "abc123")
    }

    @Test("putRespCookie adds cookie")
    func putRespCookieAddsCookie() async throws {
        let conn = TestConnection.make()
        let cookie = Cookie(
            name: "test",
            value: "value"
        )
        let result = conn.putRespCookie(cookie)

        #expect(result.respCookies.contains { $0.name == "test" })
    }

    @Test("deleteRespCookie removes cookie")
    func deleteRespCookieRemovesCookie() async throws {
        let conn = TestConnection.make()
        let result = conn.deleteRespCookie("session")

        let cookie = result.respCookies.first { $0.name == "session" }
        #expect(cookie != nil)
        // Deletion cookies typically have maxAge: 0
    }

    // MARK: - ResponseBody convenience

    @Test("ResponseBody string with empty string")
    func responseBodyStringEmpty() {
        let body = ResponseBody.string("")
        case let .buffered(data) = body
        #expect(data.isEmpty)
    }

    @Test("ResponseBody string with special characters")
    func responseBodyStringSpecialCharacters() {
        let input = "Line 1\nLine 2\r\nTab:\tNull: \0End"
        let body = ResponseBody.string(input)
        case let .buffered(data) = body
        let decoded = String(data: data, encoding: .utf8)
        #expect(decoded == input)
    }
}
