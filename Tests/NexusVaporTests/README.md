# NexusVapor Integration Tests

Comprehensive integration test suite demonstrating real-world NexusVapor usage patterns with Vapor's HTTP framework.

## Overview

This test suite validates the integration between Nexus (HTTP middleware pipeline library) and Vapor (server-side Swift HTTP framework), ensuring that request/response translation, middleware features, and error handling work correctly in realistic scenarios.

## Test Coverage

### 1. Full Request/Response Cycle
**Test**: `fullRequestResponseCycle()`

Demonstrates a complete HTTP request/response flow with JSON payloads:
- JSON request body parsing and validation
- Input validation with meaningful error responses
- JSON response serialization with proper headers
- HTTP status codes (201 Created, 400 Bad Request)
- Content-Type header handling

**Real-World Scenario**: RESTful API endpoint for user registration

### 2. Server-Sent Events (SSE) Streaming
**Test**: `sseStreaming()`

Validates asynchronous streaming responses:
- AsyncThrowingStream for real-time data streaming
- SSE-specific headers (Content-Type: text/event-stream)
- Cache control and connection keep-alive headers
- Multiple event streaming over single connection

**Real-World Scenario**: Real-time notifications, live updates, or progress streams

### 3. BeforeSend Lifecycle Hooks
**Test**: `beforeSendHooksIntegration()`

Tests the ADR-006 lifecycle hook system:
- Registering beforeSend callbacks on connections
- Modifying responses before serialization (adding custom headers)
- Execution order: pipeline → beforeSend → response translation

**Real-World Scenario**: Request ID tracking, processing time logging, response header injection

### 4. Error Handling (ADR-004)
**Test**: `errorHandlingADR004()`

Validates the ADR-004 error handling distinction:
- **HTTP-level rejections**: Using `halted()` for 4xx/5xx responses
- **Infrastructure failures**: Thrown errors converted to 500 Internal Server Error
- Error response formatting with JSON payloads

**Real-World Scenario**: Distinguishing between user errors (404) and system failures (database timeout)

### 5. Session Middleware Integration
**Test**: `sessionMiddlewareIntegration()`

Tests cookie-based session management:
- Session initialization on first request
- Session cookie signing with HMAC-SHA256
- Session data persistence across requests
- Counter increment demonstrating stateful behavior

**Real-World Scenario**: User authentication state, shopping cart, multi-step workflows

### 6. CSRF Protection Integration
**Test**: `csrfProtectionIntegration()`

Validates Cross-Site Request Forgery protection:
- CSRF token generation and storage in session
- Token validation on state-changing requests (POST/PUT/DELETE)
- Rejection of requests without valid tokens
- Integration with session middleware

**Real-World Scenario**: Form submission protection for authenticated users

### 7. Static File Serving
**Test**: `staticFileServing()`

Tests filesystem-based asset serving:
- Mapping URL prefix to filesystem directory
- Streaming files from disk
- 404 handling for missing files
- Content-Type header inference

**Real-World Scenario**: Serving CSS, JavaScript, images, and other static assets

### 8. Request Body Size Limits
**Test**: `requestBodySizeLimits()`

Validates request size enforcement:
- Small requests within limit succeed
- Oversized requests throw errors
- Configurable max body size (default 4MB)
- Error handling for exceeded limits

**Real-World Scenario**: Preventing denial-of-service attacks from large payloads

### 9. Remote IP Address Extraction
**Test**: `remoteIPAddressExtraction()`

Tests client IP address extraction:
- IP address populated from Vapor's NIO channel
- Stored in `Connection.remoteIP`
- Graceful handling when IP unavailable (testing environments)

**Real-World Scenario**: Rate limiting, geolocation, access logging

### 10. WebSocket Integration Pattern
**Test**: `webSocketIntegrationPattern()`

Demonstrates WebSocket route registration:
- WSRoute definition with pattern matching
- Connect handler for authorization
- Message handler for bidirectional communication
- Route parameter extraction

**Real-World Scenario**: Real-time chat, live dashboards, collaborative editing

## Running the Tests

### Run All Integration Tests
```bash
swift test --filter NexusVaporIntegrationTests
```

### Run a Specific Test
```bash
swift test --filter "NexusVaporIntegrationTests.test fullRequestResponseCycle"
```

### Run with Verbose Output
```bash
swift test --filter NexusVaporIntegrationTests --verbose
```

## Architecture

### Test Application Factory
```swift
let app = makeTestApplication { _, router in
    // Configure routes and middleware
}
```

The test suite uses a factory pattern to create Vapor applications configured with Nexus middleware, ensuring each test has a clean, isolated environment.

### Adapter Pattern
```swift
let adapter = NexusVaporAdapter(plug: router.handle)
let response = try await adapter.respond(to: vaporRequest, chainingTo: app.responder)
```

Tests use `NexusVaporAdapter` to convert Vapor requests to Nexus connections, run them through the plug pipeline, and convert the result back to Vapor responses.

### Middleware Pipeline
```swift
let pipeline = pipeline([
    sessionPlug(sessionConfig),
    csrfProtection(csrfConfig),
    router.handle
])
```

Tests demonstrate composing multiple middleware plugs in a pipeline, showing how session, CSRF, and routing work together.

## Key Integration Points

### Request Translation (Vapor → Nexus)
- Vapor `Request` → Nexus `Connection`
- Request body collection (up to max size)
- Remote IP extraction from NIO channel
- Headers, method, URI, query parameters

### Response Translation (Nexus → Vapor)
- Nexus `Connection` → Vapor `Response`
- Empty, buffered, and streaming response bodies
- Status code and header conversion
- BeforeSend hook execution

### Error Handling
- **HTTP errors** (4xx/5xx): Returned via `halted()`
- **Infrastructure errors**: Caught and converted to 500
- **Thrown errors**: Never propagate to Vapor

## Real-World Usage Patterns

### RESTful API with Authentication
```swift
let app = Application(.default)

let pipeline = pipeline([
    sessionPlug(sessionConfig),
    csrfProtection(csrfConfig),
    router.handle
])

app.middleware.use(NexusVaporAdapter(plug: pipeline), at: .root)
```

### Static File Serving with API
```swift
let pipeline = pipeline([
    staticFiles(StaticFilesConfig(at: "/static", from: "./public")),
    router.handle
])

app.middleware.use(NexusVaporAdapter(plug: pipeline), at: .root)
```

### WebSocket Real-Time Features
```swift
let wsRoutes = [
    WS("/ws/echo", onUpgrade: { conn in
        // Authorize WebSocket upgrade
        return WSConnection(assigns: conn.assigns, send: send)
    }, onMessage: { ws, msg in
        // Handle incoming messages
    })
]

app.nexusWebSocket(routes: wsRoutes, plug: authPipeline)
```

## Test Data and Fixtures

### Temporary File Creation
Tests use FileManager's temporary directory for static file tests, ensuring proper cleanup:

```swift
defer {
    try? FileManager.default.removeItem(at: staticDir)
}
```

### Vapor Testing Mode
```swift
let app = Application(.testing)
defer { app.shutdown() }
```

Tests use Vapor's testing environment to avoid port conflicts and ensure fast execution.

## Coverage Goals

These integration tests aim to cover:
- ✅ All public NexusVapor APIs
- ✅ All response body types (empty, buffered, streaming)
- ✅ All major middleware (session, CSRF, static files)
- ✅ Error handling paths (ADR-004)
- ✅ Lifecycle hooks (ADR-006)
- ✅ Request body size limits
- ✅ Remote IP extraction
- ✅ WebSocket integration patterns

## Known Limitations

### WebSocket Testing
Full WebSocket integration testing requires a running server with actual client connections. The current test validates the route registration pattern but doesn't test bidirectional messaging.

### Network Context
Tests run in Vapor's testing mode, which may not fully replicate production network behavior (e.g., remote IP availability, connection lifecycle).

## Future Enhancements

- [ ] Add WebSocket bidirectional messaging tests
- [ ] Test concurrent request handling
- [ ] Add performance benchmarks
- [ ] Test middleware ordering and interaction
- [ ] Add error recovery scenarios
- [ ] Test TLS/HTTPS configuration

## Related Documentation

- [Nexus Core Documentation](../../../Docs/)
- [ADR-004: Error Handling](../../../Docs/ADR/ADR-004-error-handling.md)
- [ADR-006: Lifecycle Hooks](../../../Docs/ADR/ADR-006-lifecycle-hooks.md)
- [Vapor Documentation](https://docs.vapor.codes/)

## Contributing

When adding new integration tests:

1. Follow the existing test structure and naming conventions
2. Use descriptive test names that explain the scenario
3. Include comments explaining real-world usage
4. Ensure proper cleanup (defer blocks, temp file removal)
5. Document the integration point being tested
6. Update this README with new test coverage

## License

These integration tests are part of the Nexus project and inherit its license.
