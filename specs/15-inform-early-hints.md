# Spec: Inform (103 Early Hints)

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** Nexus core (complete)

---

## 1. Goal

HTTP 103 Early Hints (RFC 8297) lets the server send preliminary headers
before the final response, allowing browsers to preload CSS, JS, and fonts
while the server is still computing the response. Elixir's `Plug.Conn.inform/3`
provides this capability.

This is a niche but standards-compliant feature that completes Nexus's
coverage of the `Plug.Conn` API surface.

---

## 2. Scope

### 2.1 The API

```swift
// Sources/Nexus/Connection+Inform.swift

extension Connection {

    /// Sends an informational (1xx) response before the final response.
    ///
    /// Used primarily for 103 Early Hints to allow browsers to preload
    /// resources while the server computes the final response.
    ///
    /// ```swift
    /// GET("/page") { conn in
    ///     var conn = conn.inform(
    ///         status: .earlyHints,
    ///         headers: [.link: "</style.css>; rel=preload; as=style"]
    ///     )
    ///     let page = try await renderExpensivePage()
    ///     return try conn.html(page)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - status: An informational status (1xx). Typically `.earlyHints` (103).
    ///   - headers: Headers to include in the informational response.
    /// - Returns: The connection unchanged (informational responses don't alter
    ///   the final response).
    public func inform(
        status: HTTPResponse.Status,
        headers: HTTPFields
    ) -> Connection
}
```

### 2.2 Behavior

1. Validate that `status` is in the 1xx range. If not, the call is a no-op
   (or a precondition failure in debug builds).
2. Store the informational response in the connection's state so the
   adapter (Hummingbird) can send it before the final response.
3. Multiple `inform` calls queue multiple informational responses.
4. The adapter is responsible for actually writing the 1xx response to
   the wire. The `Connection` just records the intent.

### 2.3 Adapter Integration

```swift
// Sources/NexusHummingbird/HummingbirdAdapter.swift (addition)

// When converting Connection → Hummingbird response, check for queued
// informational responses and send them first.
```

### 2.4 Storage

Add an `informationalResponses` field to `Connection` (or store in assigns
under an internal key) that holds an array of `(status, headers)` tuples.

---

## 3. Acceptance Criteria

- [ ] `inform(status: .earlyHints, headers: ...)` queues an informational response
- [ ] Multiple `inform` calls queue multiple responses in order
- [ ] Non-1xx status is rejected (no-op or precondition failure)
- [ ] `inform` does not alter the final response status, headers, or body
- [ ] Informational responses are accessible for adapter extraction
- [ ] Hummingbird adapter sends 103 before the final response
- [ ] Connection remains a value type (no reference semantics introduced)
- [ ] Works with existing plugs (inform + html/json response in same handler)
- [ ] `swift test` passes

---

## 4. Non-goals

- No `100 Continue` handling (that's a transport-level concern handled by the server).
- No automatic `Link` header preload detection — the caller specifies headers explicitly.
- No browser-side verification in tests (just verify the connection state).
