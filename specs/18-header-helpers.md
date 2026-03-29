# Spec 18: Header Helpers

## Summary

Add convenience helper methods for working with request and response headers, matching Elixir's `put_req_header`, `put_resp_header`, `delete_req_header`, and `delete_resp_header` functionality.

## Motivation

Currently, headers are manipulated via direct dictionary access:
```swift
// Current pattern
conn.response.headerFields["X-Custom"] = "value"
conn.response.headerFields["X-Custom"] = nil  // delete
```

This is verbose and doesn't match Plug's convenient API. Need helpers for:
- Setting request/response headers
- Deleting request/response headers
- Getting header values
- Case-insensitive header lookups

## Design

Add methods to `Connection` type:

```swift
// Response headers
func putRespHeader(_ field: String, _ value: String) -> Connection
func deleteRespHeader(_ field: String) -> Connection

// Request headers
func putReqHeader(_ field: String, _ value: String) -> Connection
func deleteReqHeader(_ field: String) -> Connection

// Get header values (case-insensitive)
func getRespHeader(_ field: String) -> String?
func getReqHeader(_ field: String) -> String?
```

## Acceptance Criteria

### Response Header Helpers
- [ ] `putRespHeader(_:_:)` sets a response header (case-insensitive storage)
- [ ] `deleteRespHeader(_:)` removes a response header
- [ ] `getRespHeader(_:)` retrieves a response header value (case-insensitive)
- [ ] Header names are normalized (e.g., "x-custom" → "X-Custom" via HTTP field naming)

### Request Header Helpers
- [ ] `putReqHeader(_:_:)` sets a request header
- [ ] `deleteReqHeader(_:)` removes a request header
- [ ] `getReqHeader(_:)` retrieves a request header value (case-insensitive)

### Integration
- [ ] All helpers return a new `Connection` (immutability preserved)
- [ ] Header helpers work with all HTTP methods (GET, POST, etc.)
- [ ] Header helpers work in pipeline composition
- [ ] Header helpers work with `halt()` to return early

### Edge Cases
- [ ] Setting header to empty string is valid
- [ ] Deleting a non-existent header is a no-op
- [ ] Header name comparison is case-insensitive per RFC 7230
- [ ] Multiple values for same header field supported (comma-separated)

### Backward Compatibility
- [ ] Existing direct `headerFields` access continues to work
- [ ] No breaking changes to existing APIs
- [ ] New methods are additive only

## Examples

### Setting Headers
```swift
// Response headers
conn = conn.putRespHeader("X-Request-ID", requestId)
conn = conn.putRespHeader("Cache-Control", "no-cache")

// Request headers (for downstream)
conn = conn.putReqHeader("X-Forwarded-For", clientIP)
```

### Deleting Headers
```swift
// Remove a header from response
conn = conn.deleteRespHeader("X-Powered-By")

// Remove a header from request
conn = conn.deleteReqHeader("X-Debug")
```

### Getting Headers
```swift
// Read request headers
if let authHeader = conn.getReqHeader("Authorization") {
    // Process authentication
}

// Read response headers (before sending)
if let contentType = conn.getRespHeader("Content-Type") {
    // Handle based on content type
}
```

### Chaining
```swift
let logger = { conn in
    conn
        .putRespHeader("X-Response-Time", "\(Date().timeIntervalSince1970)")
        .putRespHeader("X-Request-ID", conn[RequestIdKey.self] ?? "unknown")
}

let addSecurityHeaders = { conn in
    conn
        .putRespHeader("X-Frame-Options", "DENY")
        .putRespHeader("X-Content-Type-Options", "nosniff")
        .putRespHeader("X-XSS-Protection", "1; mode=block")
}
```

## Implementation Notes

- Methods added to `Connection` type
- Header storage uses `HTTPResponse.headerFields` and `HTTPRequest.headerFields`
- Use `NSLengthFormatter` or similar for header value length limits
- Consider adding `HTTPField.Name` enum for common headers (Content-Type, etc.)
