# Spec: Test Connection Recycling

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** NexusTest (complete), Connection+Cookies (complete)

---

## 1. Goal

Multi-step test flows (login → authenticated request → logout) require
carrying state between requests. In Elixir, `Plug.Test.recycle/2` copies
response cookies into a fresh request connection, simulating a browser that
persists cookies across requests.

Without this, testing authenticated flows in Nexus requires manually
extracting `Set-Cookie` headers and injecting `Cookie` headers — tedious
and error-prone.

---

## 2. Scope

### 2.1 The Function

```swift
// Sources/NexusTest/TestConnection.swift

extension TestConnection {

    /// Creates a new test connection that carries forward cookies from a
    /// previous response, simulating a browser's cookie jar.
    ///
    /// ```swift
    /// // Login
    /// let loginConn = try await app(TestConnection.build(
    ///     method: .post, path: "/login",
    ///     body: .buffered(Data("user=admin&pass=secret".utf8))
    /// ))
    ///
    /// // Authenticated request with cookies carried forward
    /// let conn = try await app(TestConnection.recycle(loginConn, path: "/dashboard"))
    /// ```
    public static func recycle(
        _ previous: Connection,
        method: HTTPRequest.Method = .get,
        path: String = "/",
        body: RequestBody = .empty,
        headers: HTTPFields = [:],
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection
}
```

### 2.2 Behavior

1. Read all `Set-Cookie` response headers from `previous.response`.
2. Extract the cookie name=value pairs (ignore attributes like `Path`,
   `HttpOnly`, `Secure`, `Max-Age`, etc. — test recycling is a simplified
   browser simulation).
3. Build a new `Connection` via `TestConnection.build(...)` with the
   supplied parameters.
4. Inject the extracted cookies as a `Cookie` request header on the new
   connection.
5. If the caller also passes explicit `Cookie` headers in `headers`,
   the recycled cookies are merged (explicit headers take precedence).

### 2.3 Cookie Handling Details

- `Set-Cookie` headers with `Max-Age=0` or `Expires` in the past should
  be excluded (the cookie was deleted).
- Multiple `Set-Cookie` headers are each parsed independently.
- Only the cookie name and value are carried forward. Path/domain scoping
  is not enforced (test simplification).

---

## 3. Acceptance Criteria

- [ ] `recycle` carries `Set-Cookie` response cookies as `Cookie` request header
- [ ] Multiple `Set-Cookie` headers are all carried forward
- [ ] `Set-Cookie` with `Max-Age=0` is excluded (deleted cookie)
- [ ] Recycled connection has the correct method, path, body, and headers
- [ ] Explicit `Cookie` header in `headers` parameter merges with / overrides recycled cookies
- [ ] Works with session plug (login → recycle → session is present)
- [ ] Works with CSRF protection (token cookie is recycled)
- [ ] Default parameters match `TestConnection.build` defaults
- [ ] `remoteIP` is not carried forward (each request is independent)
- [ ] `assigns` from previous connection are not carried forward
- [ ] `swift test` passes

---

## 4. Non-goals

- No full cookie jar implementation (no path/domain scoping, no Secure flag enforcement).
- No multi-response chaining API (recycle one connection at a time).
- No automatic CSRF token extraction from HTML bodies.
