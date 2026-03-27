# Sessions

Manage signed, cookie-based sessions with HMAC-SHA256 verification.

## Overview

Nexus provides a cookie-based session store equivalent to Elixir's `Plug.Session`
backed by `Plug.Crypto.MessageVerifier`. Session data is serialized as JSON,
signed with HMAC-SHA256 using Apple's CryptoKit, and stored in a browser cookie.

The session system has three layers:
1. **``MessageSigning``** — low-level HMAC-SHA256 sign/verify primitives
2. **``sessionPlug(_:)``** — reads and writes the session cookie automatically
3. **Session helpers** — `getSession`, `putSession`, `deleteSession`, `clearSession`
   on ``Connection``

## Setting Up Sessions

Add the session plug early in your pipeline, before any plug that needs session access:

```swift
let secret = Data("my-32-byte-minimum-secret-key!!!".utf8)

let app = pipeline([
    sessionPlug(SessionConfig(secret: secret)),
    csrfProtection(),  // needs sessions
    router.callAsFunction,
])
```

### Configuration

``SessionConfig`` controls cookie attributes:

```swift
let config = SessionConfig(
    secret: secretKey,           // Required — HMAC signing key (32+ bytes)
    cookieName: "_my_app",       // Default: "_nexus_session"
    path: "/",                   // Default: "/"
    maxAge: 3600,                // Default: 86400 (24 hours)
    secure: true,                // Default: true
    httpOnly: true,              // Default: true
    sameSite: .strict            // Default: .lax
)
```

## Reading and Writing Session Data

Use the session helpers on ``Connection``:

```swift
POST("/login") { conn in
    let user = try authenticate(conn)
    return conn
        .putSession(key: "user_id", value: user.id)
        .putSession(key: "role", value: user.role)
        .respond(status: .ok, body: .string("Logged in"))
}

GET("/profile") { conn in
    guard let userId = conn.getSession("user_id") else {
        return conn.respond(status: .unauthorized)
    }
    let user = try await fetchUser(userId)
    return try conn.json(value: user)
}

POST("/logout") { conn in
    return conn.clearSession()
        .respond(status: .ok, body: .string("Logged out"))
}
```

### Available Helpers

| Method | Description |
|--------|-------------|
| `getSession(_:)` | Read a value from the session. Returns `nil` if not present. |
| `putSession(key:value:)` | Write a key-value pair. Returns a new connection. |
| `deleteSession(_:)` | Remove a single key. Returns a new connection. |
| `clearSession()` | Remove all data and mark the cookie for deletion. |

## How It Works

### Read Phase (Request Entry)

1. The plug reads the cookie named `cookieName` from `conn.reqCookies`.
2. If present, ``MessageSigning/verify(token:secret:)`` validates the HMAC signature.
3. If valid, the JSON payload is deserialized into `[String: String]`.
4. The session dictionary is stored in `conn.assigns["_nexus_session"]`.
5. If the cookie is missing or tampered, an empty dictionary is used.

### Write Phase (Before Response)

1. A `beforeSend` callback checks whether the session was modified.
2. If modified, the session dictionary is JSON-encoded and signed with
   ``MessageSigning/sign(payload:secret:)``.
3. The signed token is set as the response cookie.
4. If `clearSession()` was called, a deletion cookie (`Max-Age=0`) is emitted.

### Security Considerations

- Session data is **signed but not encrypted**. The payload is visible to anyone
  who base64-decodes the cookie. Do not store secrets in the session.
- Browser cookies are limited to ~4 KB. Keep session values small.
- The secret key must remain stable across app restarts. Rotating the key
  invalidates all existing sessions.
- Use at least 32 bytes of cryptographically random data for the secret.

## Using MessageSigning Directly

``MessageSigning`` can be used independently for any tamper-proof token:

```swift
let secret = Data("my-secret".utf8)
let token = MessageSigning.sign(
    payload: Data("user_id=42".utf8),
    secret: secret
)
// Token format: base64url(payload).base64url(hmac)

if let payload = MessageSigning.verify(token: token, secret: secret) {
    let value = String(data: payload, encoding: .utf8)
    // "user_id=42"
}
```

## Topics

### Configuration
- ``SessionConfig``
- ``sessionPlug(_:)``

### Crypto
- ``MessageSigning``
