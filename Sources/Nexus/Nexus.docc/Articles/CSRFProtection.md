# CSRF Protection

Prevent cross-site request forgery attacks with token-based validation.

## Overview

The CSRF protection plug generates a random token, stores it in the session,
and validates it on state-changing requests (POST, PUT, PATCH, DELETE). This
is the Nexus equivalent of Elixir's `Plug.CSRFProtection`.

CSRF protection **requires sessions** — the ``sessionPlug(_:)`` must appear
earlier in the pipeline.

## Setup

```swift
let app = pipeline([
    sessionPlug(SessionConfig(secret: mySecret)),
    csrfProtection(),       // must come after sessionPlug
    router.callAsFunction,
])
```

## How It Works

### Safe Methods (GET, HEAD, OPTIONS)

These methods skip validation. The plug ensures a CSRF token exists in the
session (generating one if needed) and passes through.

### State-Changing Methods (POST, PUT, PATCH, DELETE)

The plug looks for the submitted token in two places:

1. **Form parameter** — `_csrf_token` in the request body (for HTML forms)
2. **HTTP header** — `x-csrf-token` (for JavaScript/API clients)

If the submitted token matches the session token, the request passes through.
If it does not match (or no token was submitted), the plug returns
**403 Forbidden** and halts.

## Embedding the Token

Use ``csrfToken(conn:config:)`` to get the current token for embedding in
forms or JSON responses:

```swift
GET("/form") { conn in
    let (token, conn) = csrfToken(conn: conn)
    let html = """
    <form method="post" action="/submit">
        <input type="hidden" name="_csrf_token" value="\(token)">
        <button type="submit">Submit</button>
    </form>
    """
    return conn.respond(status: .ok, body: .string(html))
}
```

For JSON APIs, return the token in the response body:

```swift
GET("/api/csrf-token") { conn in
    let (token, conn) = csrfToken(conn: conn)
    return try conn.json(value: ["csrf_token": token])
}
```

The client then includes the token in subsequent requests via the
`x-csrf-token` header:

```javascript
fetch('/api/data', {
    method: 'POST',
    headers: { 'x-csrf-token': csrfToken },
    body: JSON.stringify(data)
})
```

## Configuration

``CSRFConfig`` lets you customize the session key, form parameter name,
and header name:

```swift
let csrf = csrfProtection(CSRFConfig(
    sessionKey: "_my_csrf",         // Default: "_csrf_token"
    formParam: "authenticity_token", // Default: "_csrf_token"
    headerName: "x-csrf-token"      // Default: "x-csrf-token"
))
```

## Topics

### API
- ``CSRFConfig``
- ``csrfProtection(_:)``
- ``csrfToken(conn:config:)``
