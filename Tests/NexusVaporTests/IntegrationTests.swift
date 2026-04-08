import Testing
@testable import Nexus
@testable import NexusVapor
@testable import NexusRouter
import Vapor
import HTTPTypes
import NIOCore
import Foundation

/// Integration tests demonstrating real-world NexusVapor usage patterns.
///
/// These tests showcase how NexusVapor integrates with Vapor's request/response
/// cycle, WebSocket upgrades, middleware features, and error handling patterns.
@TestSuite("NexusVaporIntegrationTests")
struct NexusVaporIntegrationTests {

    // MARK: - Test 1: Full Request/Response Cycle

    @Test("Full request/response cycle with JSON payload")
    func fullRequestResponseCycle() async throws {
        // Setup: Create a router with a JSON API endpoint
        let router = Router()
        router.post("api/users") { conn in
            // Parse JSON body
            struct CreateUserRequest: Decodable {
                let name: String
                let email: String
            }

            guard case .buffered(let data) = conn.requestBody else {
                return conn.respond(status: .badRequest, body: .string("Missing body"))
            }

            guard let userRequest = try? JSONDecoder().decode(CreateUserRequest.self, from: data) else {
                return conn.respond(status: .badRequest, body: .string("Invalid JSON"))
            }

            // Validate input
            guard !userRequest.name.isEmpty else {
                return conn.respond(status: .badRequest, body: .string("Name required"))
            }

            guard userRequest.email.contains("@") else {
                return conn.respond(status: .badRequest, body: .string("Invalid email"))
            }

            // Simulate user creation
            let response = [
                "id": "user_123",
                "name": userRequest.name,
                "email": userRequest.email,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ] as [String: Any]

            let responseData = try JSONSerialization.data(withJSONObject: response)
            return conn.respond(
                status: .created,
                body: .buffered(responseData),
                headers: HTTPFields([
                    HTTPField(name: .contentType, value: "application/json")
                ])
            )
        }

        // Test: Create adapter and process request
        let adapter = NexusVaporAdapter(plug: router.handle)

        let request = CreateUserRequest(name: "Jane Doe", email: "jane@example.com")
        let requestBody = try JSONEncoder().encode(request)

        let app = Application(.testing)
        defer { app.shutdown() }

        var vaporRequest = Request(
            application: app,
            method: .POST,
            url: URI(path: "/api/users"),
            headers: ["Content-Type": "application/json"],
            body: .init(data: requestBody)
        )

        // Execute: Run the request through the middleware
        let response = try await adapter.respond(to: vaporRequest, chainingTo: app.responder)

        // Assert: Verify response
        #expect(response.status == .created)
        #expect(response.headers[.contentType] == "application/json")

        struct UserResponse: Decodable {
            let id: String
            let name: String
            let email: String
            let created_at: String
        }

        let responseBody = try JSONDecoder().decode(UserResponse.self, from: response.body.data!)
        #expect(responseBody.id == "user_123")
        #expect(responseBody.name == "Jane Doe")
        #expect(responseBody.email == "jane@example.com")
    }

    // MARK: - Test 2: Server-Sent Events (SSE) Streaming

    @Test("Server-Sent Events streaming response")
    func sseStreaming() async throws {
        // Setup: Create an SSE endpoint that streams real-time updates
        let router = Router()
        router.get("api/events") { conn in
            // Stream events asynchronously
            let eventStream = AsyncThrowingStream<Data, Error> { continuation in
                Task {
                    for i in 1...5 {
                        try await Task.sleep(for: .milliseconds(10))

                        let event = """
                        event: message
                        data: {"id": \(i), "text": "Event \(i)", "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"}

                        """

                        continuation.yield(Data(event.utf8))
                    }

                    continuation.finish()
                }
            }

            return conn.respond(
                status: .ok,
                body: .stream(eventStream),
                headers: HTTPFields([
                    HTTPField(name: .contentType, value: "text/event-stream"),
                    HTTPField(name: .cacheControl, value: "no-cache"),
                    HTTPField(name: .connection, value: "keep-alive")
                ])
            )
        }

        // Test: Request SSE stream
        let app = Application(.testing)
        defer { app.shutdown() }

        var vaporRequest = Request(
            application: app,
            method: .GET,
            url: URI(path: "/api/events"),
            headers: [:]
        )

        // Execute
        let adapter = NexusVaporAdapter(plug: router.handle)
        let response = try await adapter.respond(to: vaporRequest, chainingTo: app.responder)

        // Assert: Verify SSE headers
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "text/event-stream")
        #expect(response.headers[.cacheControl] == "no-cache")

        // Verify streaming body
        let bodyData = response.body.data!
        let bodyString = String(data: bodyData, encoding: .utf8)!
        #expect(bodyString.contains("event: message"))
        #expect(bodyString.contains("data: {"))
    }

    // MARK: - Test 3: BeforeSend Hooks Integration

    @Test("BeforeSend lifecycle hooks execute before response")
    func beforeSendHooksIntegration() async throws {
        // Setup: Create an endpoint with lifecycle hooks
        let router = Router()
        router.get("api/resource") { conn in
            // Register a beforeSend hook to add custom headers
            return conn.beforeSend { finalConn in
                var mutated = finalConn
                mutated = mutated.assign(key: "x-request-id", value: "req-123")
                mutated = mutated.assign(key: "x-processing-time", value: "42ms")
                return mutated
            }.respond(status: .ok, body: .string("OK"))
        }

        // Test: Make request
        let app = Application(.testing)
        defer { app.shutdown() }

        var vaporRequest = Request(
            application: app,
            method: .GET,
            url: URI(path: "/api/resource"),
            headers: [:]
        )

        // Execute
        let adapter = NexusVaporAdapter(plug: router.handle)
        let response = try await adapter.respond(to: vaporRequest, chainingTo: app.responder)

        // Assert: Verify custom headers were added by hook
        #expect(response.status == .ok)
        #expect(response.headers["x-request-id"] == "req-123")
        #expect(response.headers["x-processing-time"] == "42ms")
    }

    // MARK: - Test 4: Error Handling (ADR-004)

    @Test("Error handling distinguishes HTTP errors from infrastructure failures")
    func errorHandlingADR004() async throws {
        // Setup: Create endpoints demonstrating ADR-004 error handling
        let router = Router()

        // HTTP-level rejection (4xx/5xx via halted connection)
        router.get("api/not-found") { conn in
            return conn.halted(
                response: HTTPResponse(
                    status: .notFound,
                    headerFields: HTTPFields([
                        HTTPField(name: .contentType, value: "application/json")
                    ])
                ),
                body: .string("""
                    {"error": "Resource not found", "code": "NOT_FOUND"}
                    """)
            )
        }

        // Infrastructure failure (thrown error becomes 500)
        router.get("api/failure") { conn in
            // Simulate database timeout
            struct DatabaseTimeout: Error {}
            throw DatabaseTimeout()
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        // Test 1: HTTP-level rejection (should return 404)
        var notFoundRequest = Request(
            application: app,
            method: .GET,
            url: URI(path: "/api/not-found"),
            headers: [:]
        )

        let adapter = NexusVaporAdapter(plug: router.handle)
        let notFoundResponse = try await adapter.respond(to: notFoundRequest, chainingTo: app.responder)

        #expect(notFoundResponse.status == .notFound)
        let bodyString = String(data: notFoundResponse.body.data!, encoding: .utf8)!
        #expect(bodyString.contains("NOT_FOUND"))

        // Test 2: Infrastructure failure (should return 500)
        var failureRequest = Request(
            application: app,
            method: .GET,
            url: URI(path: "/api/failure"),
            headers: [:]
        )

        let failureResponse = try await adapter.respond(to: failureRequest, chainingTo: app.responder)

        #expect(failureResponse.status == .internalServerError)
    }

    // MARK: - Test 5: Session Middleware Integration

    @Test("Session middleware maintains state across requests")
    func sessionMiddlewareIntegration() async throws {
        // Setup: Create a pipeline with session middleware
        let secret = Data("32-byte-secret-key-for-testing!".utf8)
        let sessionConfig = SessionConfig(secret: secret)

        let router = Router()
        router.post("session/counter") { conn in
            let currentCount = conn.getSession("counter") ?? "0"
            let nextCount = (Int(currentCount) ?? 0) + 1
            var updated = conn.setSession("counter", value: String(nextCount))
            return updated.respond(
                status: .ok,
                body: .string("Count: \(nextCount)")
            )
        }

        let sessionPlug = sessionPlug(sessionConfig)

        let app = Application(.testing)
        defer { app.shutdown() }

        // Test: First request - initialize counter
        var firstRequest = Request(
            application: app,
            method: .POST,
            url: URI(path: "/session/counter"),
            headers: [:]
        )

        let adapter = NexusVaporAdapter(plug: pipeline([sessionPlug, router.handle]))
        let firstResponse = try await adapter.respond(to: firstRequest, chainingTo: app.responder)

        #expect(firstResponse.status == .ok)
        #expect(firstResponse.body.data == Data("Count: 1".utf8))

        // Verify session cookie was set
        let sessionCookie = firstResponse.cookies["_nexus_session"]
        #expect(sessionCookie != nil)

        // Test: Second request - increment counter
        var secondRequest = Request(
            application: app,
            method: .POST,
            url: URI(path: "/session/counter"),
            headers: ["Cookie": "_nexus_session=\(sessionCookie!)"]
        )

        let secondResponse = try await adapter.respond(to: secondRequest, chainingTo: app.responder)

        #expect(secondResponse.status == .ok)
        #expect(secondResponse.body.data == Data("Count: 2".utf8))
    }

    // MARK: - Test 6: CSRF Protection Integration

    @Test("CSRF protection rejects requests without valid tokens")
    func csrfProtectionIntegration() async throws {
        // Setup: Create a pipeline with CSRF protection
        let secret = Data("32-byte-secret-key-for-csrf!".utf8)
        let sessionConfig = SessionConfig(secret: secret)
        let csrfConfig = CSRFConfig()

        let router = Router()
        router.post("protected/action") { conn in
            return conn.respond(
                status: .ok,
                body: .string("Action completed")
            )
        }

        let sessionPlug = sessionPlug(sessionConfig)
        let csrfPlug = csrfProtection(csrfConfig)

        let app = Application(.testing)
        defer { app.shutdown() }

        // Test: POST without CSRF token should fail
        var postRequestNoToken = Request(
            application: app,
            method: .POST,
            url: URI(path: "/protected/action"),
            headers: [:]
        )

        let adapter = NexusVaporAdapter(
            plug: pipeline([sessionPlug, csrfPlug, router.handle])
        )

        let noTokenResponse = try await adapter.respond(to: postRequestNoToken, chainingTo: app.responder)

        #expect(noTokenResponse.status == .forbidden)
    }

    // MARK: - Test 7: Static File Serving

    @Test("Static file serving serves assets from filesystem")
    func staticFileServing() async throws {
        // Setup: Create a temporary directory with a test file
        let tempDir = FileManager.default.temporaryDirectory
        let staticDir = tempDir.appendingPathComponent("static_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staticDir, withIntermediateDirectories: true)

        let testFile = staticDir.appendingPathComponent("test.txt")
        try "Hello from static file!".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            // Cleanup
            try? FileManager.default.removeItem(at: staticDir)
        }

        // Configure static file serving
        let staticConfig = StaticFilesConfig(at: "/static", from: staticDir.path)
        let router = Router()
        router.get("**") { conn in
            return conn.respond(status: .notFound, body: .string("Not found"))
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        // Test: Request static file
        var request = Request(
            application: app,
            method: .GET,
            url: URI(path: "/static/test.txt"),
            headers: [:]
        )

        let adapter = NexusVaporAdapter(
            plug: pipeline([staticFiles(staticConfig), router.handle])
        )

        let response = try await adapter.respond(to: request, chainingTo: app.responder)

        // Assert: File should be served
        #expect(response.status == .ok)
        #expect(response.body.data == Data("Hello from static file!".utf8))

        // Test: Non-existent file should return 404
        var notFoundRequest = Request(
            application: app,
            method: .GET,
            url: URI(path: "/static/missing.txt"),
            headers: [:]
        )

        let notFoundResponse = try await adapter.respond(to: notFoundRequest, chainingTo: app.responder)

        #expect(notFoundResponse.status == .notFound)
    }

    // MARK: - Test 8: Request Body Size Limits

    @Test("Request body size limits are enforced")
    func requestBodySizeLimits() async throws {
        // Setup: Create an endpoint that accepts uploads
        let router = Router()
        router.post("api/upload") { conn in
            guard case .buffered(let data) = conn.requestBody else {
                return conn.respond(status: .badRequest, body: .string("No body"))
            }

            return conn.respond(
                status: .ok,
                body: .string("Received \(data.count) bytes")
            )
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        // Test: Small request should succeed
        let smallBody = Data("Small payload".utf8)
        var smallRequest = Request(
            application: app,
            method: .POST,
            url: URI(path: "/api/upload"),
            headers: [:],
            body: .init(data: smallBody)
        )

        let adapter = NexusVaporAdapter(
            plug: router.handle,
            maxRequestBodySize: 1024 // 1KB limit
        )

        let smallResponse = try await adapter.respond(to: smallRequest, chainingTo: app.responder)

        #expect(smallResponse.status == .ok)

        // Test: Oversized request should fail
        let largeBody = Data(repeating: 0, count: 2048) // 2KB exceeds limit
        var largeRequest = Request(
            application: app,
            method: .POST,
            url: URI(path: "/api/upload"),
            headers: [:],
            body: .init(data: largeBody)
        )

        // The adapter should throw when body exceeds max size
        await #expect(throws: Error.self) {
            try await adapter.respond(to: largeRequest, chainingTo: app.responder)
        }
    }

    // MARK: - Test 9: Remote IP Address Extraction

    @Test("Remote IP address is extracted from Vapor request")
    func remoteIPAddressExtraction() async throws {
        // Setup: Create an endpoint that logs the remote IP
        let router = Router()
        router.get("api/ip") { conn in
            let remoteIP = conn.remoteIP ?? "unknown"
            return conn.respond(
                status: .ok,
                body: .string("Your IP: \(remoteIP)")
            )
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        // Test: Make request (in testing, remote IP may be nil)
        var request = Request(
            application: app,
            method: .GET,
            url: URI(path: "/api/ip"),
            headers: [:]
        )

        let adapter = NexusVaporAdapter(plug: router.handle)
        let response = try await adapter.respond(to: request, chainingTo: app.responder)

        #expect(response.status == .ok)

        let bodyString = String(data: response.body.data!, encoding: .utf8)!
        #expect(bodyString.contains("Your IP:"))
    }

    // MARK: - Test 10: WebSocket Integration Pattern

    @Test("WebSocket integration demonstrates route registration pattern")
    func webSocketIntegrationPattern() async throws {
        // This test verifies the WebSocket integration interface exists
        // Real WebSocket testing requires a running server with actual connections

        // Verify we can create WebSocket routes
        let wsRoute = WSRoute(
            pattern: "/ws/echo",
            connectHandler: { conn in
                // Authorization logic would go here
                return WSConnection(assigns: conn.assigns, send: { _ in })
            },
            messageHandler: { ws, msg in
                // Message handling would go here
                return ()
            }
        )

        // Verify route matching works
        let params = wsRoute.match("/ws/echo")
        #expect(params != nil)

        let noMatch = wsRoute.match("/ws/other")
        #expect(noMatch == nil)
    }

    // MARK: - Supporting Types

    private struct CreateUserRequest: Encodable {
        let name: String
        let email: String
    }
}
