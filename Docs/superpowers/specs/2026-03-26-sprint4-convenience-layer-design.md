# Sprint 4: Convenience Layer for DonutShop Integration

**Date:** 2026-03-26
**Status:** Proposed
**Goal:** Close the practical gaps between Nexus and a real Hummingbird app (DonutShop) by adding query params, JSON encode/decode, and ergonomic error handling.

---

## Context

Nexus has a complete pipeline model (Sprints 0-3) but lacks the convenience APIs that real HTTP handlers need daily. DonutShop — a Hummingbird 2 app with Spectro ORM — uses four patterns that Nexus cannot express today:

1. Query parameter access (`request.uri.queryParameters.get("q")`)
2. JSON body decoding (`request.decode(as: T.self, context:)`)
3. JSON response encoding (returns `String` from `encodeJSON()` helper)
4. Throwing HTTP errors (`throw HTTPError(.notFound, message: "...")`)

All four features are additive — no existing files change. All live in the `Nexus` core target.

---

## Feature 1: Query Params

**File:** `Sources/Nexus/Connection+QueryParams.swift`

A computed property on `Connection` that parses the query string from `request.path`.

```swift
extension Connection {
    /// Query parameters parsed from the request URL.
    ///
    /// Parses the query string portion of ``request/path`` on each access.
    /// For duplicate keys, the first value wins (matching Elixir Plug's
    /// `fetch_query_params` semantics). Values are percent-decoded.
    ///
    /// Returns an empty dictionary if there is no query string.
    public var queryParams: [String: String] {
        guard let path = request.path,
              let queryStart = path.firstIndex(of: "?") else {
            return [:]
        }
        let queryString = path[path.index(after: queryStart)...]
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard let key = parts.first else { continue }
            let rawKey = String(key).removingPercentEncoding ?? String(key)
            let rawValue: String
            if parts.count > 1 {
                rawValue = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            } else {
                rawValue = ""
            }
            if params[rawKey] == nil {
                params[rawKey] = rawValue
            }
        }
        return params
    }
}
```

**Design notes:**
- Parsed on each access (no caching). Connection is a value type — caching would require mutation or a stored property. For the small query strings typical in APIs, parsing is cheap enough that caching adds complexity without measurable benefit.
- First-value-wins for duplicate keys matches Elixir Plug behavior.
- Percent-decoding applied to both keys and values, with fallback to raw string on malformed encoding (same pattern as `PathPattern.match`).
- `import Foundation` is needed for `removingPercentEncoding` — already imported in `Connection.swift`.

**Tests:**
- `test_connection_queryParams_emptyWhenNoQueryString`
- `test_connection_queryParams_parsesSingleParam`
- `test_connection_queryParams_parsesMultipleParams`
- `test_connection_queryParams_firstValueWinsForDuplicates`
- `test_connection_queryParams_percentDecodesKeysAndValues`
- `test_connection_queryParams_handlesEmptyValue`
- `test_connection_queryParams_handlesNoPath`

---

## Feature 2: JSON Body Decoding

**File:** `Sources/Nexus/Connection+JSON.swift`

A method on `Connection` that decodes the buffered request body as JSON.

```swift
extension Connection {
    /// Decodes the buffered request body as JSON into the given type.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode into.
    ///   - decoder: The JSON decoder to use. Defaults to a stock `JSONDecoder()`.
    /// - Returns: The decoded value.
    /// - Throws: `NexusHTTPError(.badRequest)` if the body is empty or not
    ///   buffered. `DecodingError` if the JSON does not match the type.
    public func decode<T: Decodable & Sendable>(
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard case .buffered(let data) = requestBody else {
            throw NexusHTTPError(.badRequest, message: "Missing request body")
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NexusHTTPError(.badRequest, message: "Invalid JSON: \(error.localizedDescription)")
        }
    }
}
```

**Design notes:**
- Throws `NexusHTTPError(.badRequest)` for empty/stream bodies — this is caught by `rescueErrors` and becomes a 400 response. This is a pragmatic exception to ADR-004's "don't throw for HTTP errors" rule: decode failures in a handler are inherently request-validation errors, and forcing `guard case .buffered` + halt in every handler would be miserable ergonomics.
- `DecodingError` from `JSONDecoder` is caught and re-thrown as `NexusHTTPError(.badRequest)` with the decode error description. This ensures malformed JSON from a client produces a 400 Bad Request, not a 500 Internal Server Error.
- Default `JSONDecoder()` with no configuration. Callers who need `keyDecodingStrategy` etc. pass their own decoder. `JSONDecoder` and `JSONEncoder` are `@unchecked Sendable` in Foundation and safe to use as default parameters under Swift 6 strict concurrency.

**Tests:**
- `test_connection_decode_decodesValidJSON`
- `test_connection_decode_throwsForEmptyBody`
- `test_connection_decode_throwsForInvalidJSON`
- `test_connection_decode_usesCustomDecoder`
- `test_connection_decode_errorIsBadRequest`

---

## Feature 3: JSON Response Helper

**File:** `Sources/Nexus/Connection+JSON.swift` (same file as Feature 2)

A method on `Connection` that encodes an `Encodable` value as the response body and halts.

```swift
extension Connection {
    /// Encodes the given value as JSON, sets it as the response body with
    /// `Content-Type: application/json`, and halts the connection.
    ///
    /// Unlike ``respond(status:body:)`` which replaces the entire response,
    /// this method preserves existing response headers and only sets the
    /// status, body, content-type header, and halt flag.
    ///
    /// - Parameters:
    ///   - status: The HTTP response status. Defaults to `.ok`.
    ///   - value: The `Encodable` value to serialize as JSON.
    ///   - encoder: The JSON encoder to use. Defaults to a stock `JSONEncoder()`.
    /// - Returns: A halted connection with the JSON response body.
    /// - Throws: `EncodingError` if the value cannot be encoded.
    public func json<T: Encodable & Sendable>(
        status: HTTPResponse.Status = .ok,
        value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Connection {
        let data = try encoder.encode(value)
        var copy = self
        copy.response.status = status
        copy.response.headerFields[.contentType] = "application/json"
        copy.responseBody = .buffered(data)
        copy.isHalted = true
        return copy
    }
}
```

**Design notes:**
- Sets `Content-Type: application/json` automatically — the one header convenience that earns its keep.
- Preserves existing response headers (unlike `respond()` which creates a fresh `HTTPResponse`). This means headers set by upstream middleware (CORS, security headers, etc.) survive through `json()`.
- `throws` because `JSONEncoder.encode` can throw `EncodingError`. This is a genuine infrastructure error (broken Encodable conformance), not an HTTP error, so it correctly propagates to the adapter's 500 handler.

**Tests:**
- `test_connection_json_setsStatusAndBody`
- `test_connection_json_setsContentTypeHeader`
- `test_connection_json_preservesExistingHeaders`
- `test_connection_json_haltsConnection`
- `test_connection_json_defaultsToOKStatus`
- `test_connection_json_encodesNestedStructures`

---

## Feature 4: NexusHTTPError + rescueErrors

**File:** `Sources/Nexus/NexusHTTPError.swift`

A throwable error type for intentional HTTP responses, plus a plug wrapper that catches them. Requires `import HTTPTypes` for `HTTPResponse.Status`.

```swift
/// An error representing an intentional HTTP response.
///
/// Throw this from a handler when you want to signal an HTTP error status
/// without manually building a halted response. The ``rescueErrors(_:)``
/// plug wrapper catches these and converts them to halted connections.
///
/// ```swift
/// GET("/users/:id") { conn in
///     guard let user = try await findUser(conn.params["id"]) else {
///         throw NexusHTTPError(.notFound, message: "User not found")
///     }
///     return try conn.json(value: user)
/// }
/// ```
public struct NexusHTTPError: Error, Sendable {
    /// The HTTP status code for the response.
    public let status: HTTPResponse.Status

    /// A human-readable error message included in the response body.
    public let message: String

    /// Creates an HTTP error with the given status and message.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code (e.g., `.notFound`, `.badRequest`).
    ///   - message: An optional message for the response body. Defaults to empty.
    public init(_ status: HTTPResponse.Status, message: String = "") {
        self.status = status
        self.message = message
    }
}

/// Wraps a plug (or pipeline) so that any ``NexusHTTPError`` thrown inside
/// is caught and converted to a halted response.
///
/// Non-`NexusHTTPError` errors pass through to the server adapter's
/// generic 500 handler, preserving the ADR-004 contract.
///
/// ```swift
/// let app = rescueErrors(pipeline([logger, auth, router]))
/// let adapter = NexusHummingbirdAdapter(plug: app)
/// ```
///
/// - Parameter plug: The plug or pipeline to wrap.
/// - Returns: A plug that catches `NexusHTTPError` and halts gracefully.
public func rescueErrors(_ plug: @escaping Plug) -> Plug {
    { conn in
        do {
            return try await plug(conn)
        } catch let error as NexusHTTPError {
            var copy = conn
            copy.response.status = error.status
            copy.responseBody = error.message.isEmpty
                ? .empty
                : .string(error.message)
            copy.isHalted = true
            return copy
        }
    }
}
```

**Design notes:**
- `rescueErrors` only catches `NexusHTTPError`. All other errors (database failures, I/O, encoding errors) propagate to the adapter's 500 handler per ADR-004.
- The wrapper returns a `Plug`, so it composes naturally: `rescueErrors(pipeline([...]))`.
- Builds the halted response manually (not via `respond()`) to preserve headers set by upstream middleware. This matches `json()`'s header-preserving behavior.
- The message becomes the response body as a plain string. If the caller wants JSON error bodies, they can write a custom rescue plug or we can add a JSON variant later.
- `NexusHTTPError` lives in `Nexus` core, not the router — any plug can throw it.
- **Implementation order:** Feature 4 (`NexusHTTPError.swift`) must be implemented before Feature 2 (`Connection+JSON.swift`), since `decode(as:)` throws `NexusHTTPError`.

**Tests:**
- `test_nexusHTTPError_storesStatusAndMessage`
- `test_rescueErrors_catchesNexusHTTPError_returnsHaltedResponse`
- `test_rescueErrors_setsCorrectStatusCode`
- `test_rescueErrors_includesMessageInBody`
- `test_rescueErrors_emptyMessage_returnsEmptyBody`
- `test_rescueErrors_nonNexusError_propagates`
- `test_rescueErrors_noError_passesThroughNormally`

---

## File Summary

| File | Target | What |
|------|--------|------|
| `Sources/Nexus/Connection+QueryParams.swift` | Core (new) | `queryParams` computed property |
| `Sources/Nexus/Connection+JSON.swift` | Core (new) | `decode(as:)` + `json(status:value:)` |
| `Sources/Nexus/NexusHTTPError.swift` | Core (new) | `NexusHTTPError` + `rescueErrors(_:)` |
| `Tests/NexusTests/QueryParamsTests.swift` | Tests (new) | Query param tests |
| `Tests/NexusTests/JSONTests.swift` | Tests (new) | Decode + encode tests |
| `Tests/NexusTests/NexusHTTPErrorTests.swift` | Tests (new) | Error + rescue tests |

All additive. No existing files modified.

---

## DonutShop Migration Example

Before (Hummingbird):
```swift
group.get("search") { request, context -> String in
    let q = request.uri.queryParameters.get("q") ?? ""
    let donuts = try await db.repo().where { ... }.all()
    return try encodeJSON(donuts.map { ... })
}
```

After (Nexus):
```swift
GET("/donuts/search") { conn in
    let q = conn.queryParams["q"] ?? ""
    let donuts = try await db.repo().where { ... }.all()
    return try conn.json(value: donuts.map { ... })
}
```

Before (Hummingbird):
```swift
group.post { request, context -> String in
    let body = try await request.decode(as: CreateDonut.self, context: context)
    guard ... else { throw HTTPError(.badRequest, message: "Invalid") }
    ...
}
```

After (Nexus):
```swift
POST("/donuts") { conn in
    let body = try conn.decode(as: CreateDonut.self)
    guard ... else { throw NexusHTTPError(.badRequest, message: "Invalid") }
    ...
}
```

---

## What This Does NOT Include (Deferred)

- ADR for this sprint (the features are small enough that the spec suffices)
- Convenience header helpers (`putRespHeader`, `putRespContentType`) — direct field access is fine
- `put_status` standalone helper — `respond()` and `json()` cover the common cases
- Multipart/URL-encoded body parsing — DonutShop only uses JSON
- Cookie/session support — DonutShop has no auth
- Test helpers module — constructing `Connection` directly is workable
