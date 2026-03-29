# Spec: Debugger Plug

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** Nexus core (complete), Connection+HTML (complete)

---

## 1. Goal

During development, unhandled errors produce opaque 500 responses. Elixir's
`Plug.Debugger` catches exceptions and renders a detailed HTML error page
showing the error message, stack trace, connection state, and request
details — dramatically speeding up debugging.

Nexus should provide the same dev-time experience.

---

## 2. Scope

### 2.1 The Plug

```swift
// Sources/Nexus/Plugs/Debugger.swift

/// Catches pipeline errors and renders a detailed HTML debug page.
///
/// **Development only.** Never enable in production — it exposes internals.
///
/// ```swift
/// let app = pipeline([
///     debugger(),     // Must be first to catch all errors
///     requestId(),
///     router,
/// ])
/// ```
public func debugger(style: DebugPageStyle = .default) -> Plug

public enum DebugPageStyle: Sendable {
    /// Built-in styled HTML page.
    case `default`
    /// Plain text (useful for API-first dev or curl debugging).
    case plainText
}
```

### 2.2 Behavior

1. Wrap downstream pipeline execution in a `do/catch`.
2. If no error → pass through unchanged.
3. On error → render a debug response:
   - Status: the error's status code if `NexusHTTPError`, otherwise 500.
   - Body: HTML (or plain text) page containing:
     - Error type and message
     - Request method, path, and headers
     - Query parameters
     - Connection assigns (redacting values for keys containing
       "secret", "password", "token", "key")
     - Pipeline stack hint (which plug threw, if available from the error)

### 2.3 Redaction

Assigns keys matching the patterns `secret`, `password`, `token`, `key`
(case-insensitive substring) have their values replaced with `"[REDACTED]"`
in the debug page. This prevents accidental exposure of credentials even
in development.

### 2.4 HTML Template

The HTML page is a self-contained string literal (no external template
files). It includes inline CSS for readability — dark background, monospace
font, collapsible sections. Keep it simple: no JavaScript required, no
external resources.

---

## 3. Acceptance Criteria

- [ ] Pipeline error → returns HTML debug page with error details
- [ ] Debug page includes error type and message
- [ ] Debug page includes request method, path, and headers
- [ ] Debug page includes query parameters
- [ ] Debug page includes connection assigns (redacted)
- [ ] Values for keys matching "secret"/"password"/"token"/"key" are `[REDACTED]`
- [ ] `NexusHTTPError` → uses error's status code
- [ ] Non-Nexus error → status 500
- [ ] `style: .plainText` → plain text body instead of HTML
- [ ] No error in pipeline → passes through unchanged
- [ ] Self-contained HTML (no external CSS/JS/image dependencies)
- [ ] Composable in a pipeline with other plugs
- [ ] `swift test` passes

---

## 4. Non-goals

- No interactive REPL or live reload.
- No source code display (requires source map integration).
- No production error reporting (use telemetry + external service).
- No custom template support — one built-in style.
