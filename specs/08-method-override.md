# Spec: Method Override Plug

**Status:** Proposed
**Date:** 2026-03-28
**Depends on:** Nexus core (complete), Connection+FormParams (complete)

---

## 1. Goal

HTML forms only support GET and POST. To use PUT, PATCH, and DELETE from
server-rendered forms, Phoenix/Plug provides `Plug.MethodOverride` — a plug
that reads a `_method` field from the POST body and rewrites the request
method before it hits the router.

```html
<form method="post" action="/donuts/<%= donut.id %>">
  <input type="hidden" name="_method" value="DELETE">
  <button type="submit">Delete</button>
</form>
```

The router sees a DELETE request. No JavaScript required.

Nexus needs the same to reach feature parity with Plug for server-rendered
applications.

---

## 2. Scope

### 2.1 The Plug

```swift
// Sources/Nexus/Plugs/MethodOverride.swift

/// Rewrites the HTTP method of a POST request when a `_method` form parameter
/// is present. Only POST requests are rewritten — GET, PUT, PATCH, DELETE
/// pass through unchanged.
///
/// Allowed override values: `PUT`, `PATCH`, `DELETE` (case-insensitive).
/// Any other value is ignored (the request stays POST).
///
/// Must be placed in the pipeline **after** body parsing is available
/// (i.e. the request body must be buffered) and **before** the router.
///
/// ```swift
/// let app = pipeline([
///     requestId(),
///     methodOverride(),
///     router,
/// ])
/// ```
public func methodOverride() -> Plug
```

### 2.2 Behavior

1. If the request method is not POST → pass through, no change.
2. Read `conn.formParams["_method"]`.
3. If the value uppercased is `PUT`, `PATCH`, or `DELETE` → rewrite
   `conn.request.method` to the corresponding `HTTPRequest.Method`.
4. Otherwise → pass through, request stays POST.

### 2.3 Security

- Only POST can be overridden. A GET with `?_method=DELETE` in the query
  string must NOT trigger a rewrite (GET should be safe/idempotent).
- Only rewrite to `PUT`, `PATCH`, `DELETE`. Overriding to `GET`, `HEAD`,
  `OPTIONS`, or `CONNECT` is not allowed.

### 2.4 Query Parameter Support

Plug also supports `_method` in the query string (for POST requests only).
Check `conn.formParams["_method"]` first, fall back to
`conn.queryParams["_method"]`.

---

## 3. Acceptance Criteria

- [ ] `POST` with `_method=DELETE` → request method becomes `DELETE`
- [ ] `POST` with `_method=PUT` → request method becomes `PUT`
- [ ] `POST` with `_method=PATCH` → request method becomes `PATCH`
- [ ] `POST` with `_method=delete` (lowercase) → works (case-insensitive)
- [ ] `POST` with no `_method` → stays `POST`
- [ ] `POST` with `_method=GET` → stays `POST` (not allowed)
- [ ] `POST` with `_method=OPTIONS` → stays `POST` (not allowed)
- [ ] `GET` with `?_method=DELETE` → stays `GET` (only POST is rewritten)
- [ ] Query param fallback: `POST` to `?_method=PUT` with no form body → becomes `PUT`
- [ ] Form param takes precedence over query param
- [ ] Plug is composable in the pipeline (works with requestId, router, etc.)
- [ ] `swift test` passes

---

## 4. Non-goals

- No `_method` header support (Plug doesn't support it either).
- No custom parameter name — `_method` is the convention.
- No CSRF integration in this spec (that's the existing `csrfProtection` plug).
