# Spec 23: Plug.Test Helpers

## Summary

Add test helpers for creating test connections and invoking plugs, matching Elixir's `Plug.Test` functionality.

## Motivation

Elixir's `Plug.Test`:
```elixir
# Create test connection
conn = conn(:get, "/users/123")

# Call plug directly
result = MyPlug.call(conn, %{})

# Assert on connection
assert result.status == 200
assert result.resp_body == "User 123"
```

Current Nexus testing:
```swift
// Manual connection creation
var request = HTTPRequest(method: .GET, uri: "/users/123")
let conn = Connection(request: request)

// Test plug
let result = await plug(conn)
```

Need convenient helpers for:
- Creating test connections with various methods/paths
- Calling plugs with optional configuration
- Asserting on connection state

## Design

### Test Connection Factory
```swift
extension Connection {
    static func make(
        method: HTTPRequest.Method = .GET,
        uri: String = "/",
        headers: [String: String] = [:],
        body: RequestBody = .empty
    ) -> Connection
}
```

### Plug Invocation Helpers
```swift
extension Plug {
    func callTest(_ conn: Connection, _ options: [String: AnySendable] = [:]) async throws -> Connection {
        // Call plug with options if ConfigurablePlug
        // Or just call(conn) if function plug
    }
}
```

### Assertion Helpers
```swift
// For Swift Testing
@discardableResult
func assertStatus(_ conn: Connection, _ expected: HTTPResponse.Status, file: StaticString = #filePath, line: UInt = #line) -> Connection

@discardableResult
func assertHeader(_ conn: Connection, _ field: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) -> Connection

func assertBodyContains(_ conn: Connection, _ expected: String, file: StaticString = #filePath, line: UInt = #line)
```

## Acceptance Criteria

### Connection Creation
- [ ] `Connection.make(method:uri:headers:body:)` creates a test connection
- [ ] Default method is GET
- [ ] Default URI is /
- [ ] Headers can be specified
- [ ] Body can be specified

### Plug Invocation
- [ ] Plugs can be invoked directly in tests
- [ ] ConfigurablePlug options can be passed
- [ ] Async plugs are properly awaited

### Response Assertions
- [ ] `assertStatus(_:_:)` checks response status
- [ ] `assertHeader(_:_:_:)` checks response header value
- [ ] `assertBodyContains(_:_:)` checks response body
- [ ] `assertBodyEquals(_:_:)` checks exact body match

### Error Assertions
- [ ] `assertRaisesError(_:_:)` checks plug throws expected error
- [ ] `assertHalted(_:)` checks connection is halted
- [ ] `assertNotHalted(_:)` checks connection is not halted

### Integration
- [ ] Test helpers work with Swift Testing framework
- [ ] Test helpers work with existing Nexus test infrastructure
- [ ] No breaking changes to existing tests

## Examples

### Basic Test
```swift
@Test("GET /users returns 200")
func testUsersRoute() async throws {
    let conn = Connection.make(method: .GET, uri: "/users")
    let result = await myRouter.call(conn)

    #expect(result.response.status == .ok)
    #expect(result.response.headerFields["Content-Type"]?.contains("json") == true)
}
```

### Plug Testing
```swift
@Test("RequestLogger adds timestamp header")
func testRequestLogger() async throws {
    let conn = Connection.make(method: .GET, uri: "/test")
    let result = await requestLogger.call(conn)

    #expect(result.response.headerFields["X-Request-Timestamp"] != nil)
}
```

### Error Testing
```swift
@Test("BasicAuth rejects missing credentials")
func testBasicAuthRejects() async throws {
    let conn = Connection.make(
        method: .GET,
        uri: "/protected",
        headers: [:]  // No Authorization header
    )

    let result = await basicAuth.call(conn)

    #expect(result.isHalted == true)
    #expect(result.response.status == .unauthorized)
}
````

### With Options
```swift
@Test("RateLimiter allows under limit")
func testRateLimiterAllowed() async throws {
    let options = RateLimiter.Options(maxRequests: 100, windowSeconds: 60)
    let plug = try RateLimiter(options: options)

    let conn = Connection.make(method: .GET, uri: "/api")
    let result = await plug.call(conn)

    #expect(result.isHalted == false)
}
```

### Custom Assertions
```swift
func assertRedirect(
    _ conn: Connection,
    to expectedLocation: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    #expect(conn.isHalted, file: file, line: line)
    #expect(conn.response.status == .found, file: file, line: line)
    #expect(conn.response.headerFields["Location"] == expectedLocation, file: file, line: line)
}

// Usage
@Test("SSLRedirect redirects HTTP to HTTPS")
func testSSLRedirect() async throws {
    let conn = Connection.make(
        method: .GET,
        uri: "http://example.com",
        headers: ["X-Forwarded-Proto": "http"]
    )
    let result = await sslRedirect.call(conn)

    assertRedirect(result, to: "https://example.com")
}
```

## Implementation Notes

- Add to `Sources/NexusTest/TestHelpers.swift` or similar
- Follow Swift Testing conventions (`#expect` not `XCTAssert`)
- Provide convenient defaults for common test scenarios
- Consider adding `TestConnection` subclass for additional test helpers
- Document common patterns and anti-patterns
