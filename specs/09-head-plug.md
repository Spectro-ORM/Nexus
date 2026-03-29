# Spec: Head Plug

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** Nexus core (complete)

---

## 1. Goal

HTTP clients send HEAD requests to retrieve headers without a response body.
Most web applications only define GET routes. Per RFC 9110 §9.3.2, a server
MUST respond to HEAD identically to GET except it MUST NOT return a body.

Elixir's `Plug.Head` solves this by converting HEAD → GET before routing, then
stripping the response body after the pipeline runs. Without this, every GET
route would need a duplicate HEAD handler or HEAD requests would 404.

Nexus needs the same plug for HTTP compliance.

---

## 2. Scope

### 2.1 The Plug

```swift
// Sources/Nexus/Plugs/Head.swift

/// Converts HEAD requests to GET so that existing GET routes handle them,
/// then strips the response body.
///
/// Place this early in the pipeline, before the router:
///
/// ```swift
/// let app = pipeline([
///     head(),
///     requestId(),
///     router,
/// ])
/// ```
public func head() -> Plug
```

### 2.2 Behavior

1. If the request method is not HEAD → pass through unchanged.
2. Rewrite `conn.request.method` from HEAD to GET.
3. Run the rest of the pipeline (the plug calls `next(conn)` or returns
   immediately — depending on whether this is a before-only plug or wraps
   the pipeline). Since Nexus plugs are functions composed with `pipeline()`,
   this plug rewrites the method and the downstream plugs see GET.
4. A `registerBeforeSend` callback strips the response body to `.empty`
   before the response is sent, preserving headers and status.

### 2.3 Implementation Notes

- Use `registerBeforeSend` to strip the body. This ensures the body is
  removed regardless of what downstream plugs set.
- The `Content-Length` header (if present) should be preserved — it tells
  the client how large the GET response *would* be.
- The original method is rewritten on the connection struct. No need to
  store the original method in assigns — the body stripping is unconditional
  via the before-send hook.

---

## 3. Acceptance Criteria

- [ ] HEAD request to a GET route → returns 200 with correct headers and empty body
- [ ] HEAD request preserves `Content-Length` header from the GET response
- [ ] HEAD request preserves `Content-Type` header from the GET response
- [ ] GET request → passes through unchanged, body intact
- [ ] POST request → passes through unchanged
- [ ] HEAD to a non-existent route → returns 404 (same as GET would)
- [ ] HEAD request with a pipeline that sets response body → body is stripped
- [ ] Works with `respondTo` (content negotiation still sees the right headers)
- [ ] Composable in a pipeline with other plugs (requestId, logger, router)
- [ ] `swift test` passes

---

## 4. Non-goals

- No conditional body stripping — all HEAD responses get bodies stripped.
- No HEAD-specific route matching in the router (this is a pipeline plug only).
