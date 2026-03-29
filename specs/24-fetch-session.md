# Spec 24: Fetch Session Helper

## Summary

Add `fetch_session/2` helper function for explicitly fetching session data, matching Elixir's Plug.Session functionality.

## Motivation

In Elixir's Plug.Session:
```elixir
# Session is auto-fetched by plug
plug :fetch_session

# Can also manually fetch
conn = fetch_session(conn, opts)

# Check if session exists
session_exists?(conn)
```

Current Nexus session implementation:
```swift
// Session is automatically fetched by sessionPlug
pipeline([
    sessionPlug(config: config),
    // session is available via conn[SessionKey.self]
])
```

Need explicit fetch when:
- Session is optional (not always fetch)
- Multiple session fetches needed
- Conditional session loading
- Testing without full session plug

## Design

### Session Fetch Function
```swift
func fetchSession(_ conn: Connection, config: SessionPlug.Config) -> Connection
```

### Session State
Track session fetch status:
```swift
extension Connection {
    var isSessionFetched: Bool { get }
    var sessionFetchError: Error? { get }
}
````

### Session Access
```swift
extension Connection {
    func fetchSession(_ config: SessionPlug.Config) -> Connection
    func fetchSessionIfMissing(_ config: SessionPlug.Config) -> Connection
    func clearSession() -> Connection
}
```

## Acceptance Criteria

### Session Fetching
- [ ] `fetchSession(_:config:)` loads session from cookie
- [ ] `fetchSession(_:config:)` handles missing/invalid cookies gracefully
- [ ] Session data is available in `conn[SessionKey.self]` after fetch

### Session State Tracking
- [ ] `isSessionFetched` returns true after successful fetch
- [ ] `isSessionFetched` returns false if not fetched
- [ ] `sessionFetchError` contains error if fetch failed

### Conditional Fetching
- [ ] `fetchSessionIfMissing(_:)` only fetches if not already fetched
- [ ] Multiple fetches with same config work correctly
- [ ] Fetch with different config updates session

### Session Clearing
- [ ] `clearSession()` removes session data
- [ ] `clearSession()` clears session cookie
- [ ] `clearSession()` returns new connection

### Error Handling
- [ ] Invalid cookie format is handled
- [ ] Expired sessions are handled
- [ ] Signature verification failures are handled
- [ ] Session errors don't halt the pipeline (unless configured)

## Examples

### Basic Session Fetch
```swift
// Explicitly fetch session
let withSession = fetchSession(conn, config: sessionConfig)
let userId = withSession[SessionKey.self]?["user_id"]
````

### Optional Session
```swift
// Session is optional - don't halt if missing
func handleRequest(conn: Connection) async throws -> Connection {
    let conn = conn.fetchSession(sessionConfig)

    if let userId = conn[SessionKey.self]?["user_id"] {
        // User is logged in
        return showDashboard(conn, userId: userId)
    } else {
        // User is anonymous
        return showPublicPage(conn)
    }
}
```

### Session Refresh
```swift
// Refresh session expiry on each request
func refreshSession(conn: Connection) async -> Connection {
    guard conn.isSessionFetched else {
        return conn.fetchSession(sessionConfig)
    }

    // Re-sign session to extend expiry
    return conn
}
```

### Session Cleanup
```swift
// Clear session on logout
func logout(conn: Connection) async throws -> Connection {
    let conn = conn.clearSession()

    return conn
        .respond(status: .ok)
        .setBody("Logged out")
        .halted()
}
```

### Conditional Session
```swift
// Only fetch session for authenticated routes
func routeHandler(conn: Connection) async throws -> Connection {
    let path = conn.request.path ?? "/"

    switch path {
    case "/login", "/signup":
        // Don't fetch session for auth pages
        return handleAuthPages(conn)

    default:
        // Fetch session for other routes
        let conn = conn.fetchSession(sessionConfig)
        return handleProtected(conn)
    }
}
```

## Implementation Notes

- Add `fetchSession(_:config:)` to `Connection.swift`
- Track session state in Connection (private property)
- Session fetch should not throw - handle errors gracefully
- Consider adding `SessionPlug.Config.fetchMode` (always, ifMissing, never)
- Test with valid/invalid/empty/missing cookies
