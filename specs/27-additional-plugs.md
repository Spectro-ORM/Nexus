# Spec 27: Additional Built-in Plugs

## Summary

Add additional built-in plugs for common web middleware patterns, bringing feature parity with Elixir's Plug ecosystem.

## Motivation

Elixir's Plug includes these built-in plugs:
- `Plug.Logger` - Request logging
- `Plug.Head` - HEAD to GET conversion
- `Plug.MethodOverride` - Method tunneling
- `Plug.Parsers` - Body parsing (JSON, form, etc.)
- `Plug.RequestId` - Request ID generation
- `Plug.Session` - Session management
- `Plug.Static` - Static file serving
- `Plug.SSL` - SSL redirect
- `Plug.BasicAuth` - Basic authentication
- `Plug.CSRFProtection` - CSRF protection

Nexus has most of these, but missing:
- ` Plug.Head` - HEAD to GET (has it but may need enhancement)
- `Plug.Parsers` - Comprehensive body parsing (has BodyParser but may need expansion)
- SSL redirect with more options
- Additional conveniences

## Design

### New Plugs to Add

#### 1. ContentNegotiation Plug
```swift
struct ContentNegotiation: ModulePlug {
    enum NegotiationError: Error {
        case notAcceptable([String])
    }

    let supportedTypes: [MediaType]
    let defaultType: MediaType?

    func call(_ conn: Connection) async throws -> Connection {
        // Check Accept header
        // Match against supported types
        // Set Content-Type on response
    }
}
````

#### 2. Timeout Plug
```swift
struct Timeout: ModulePlug {
    let duration: TimeAmount

    func call(_ conn: Connection) async throws -> Connection {
        // Wrap plug execution in timeout
        // Return 503 on timeout
    }
}
````

#### 3. Compression Plug
```swift
struct Compression: ModulePlug {
    enum Algorithm {
        case gzip
        case brotli
    }

    let algorithms: [Algorithm]
    let minLength: Int

    func call(_ conn: Connection) async throws -> Connection {
        // Check Accept-Encoding
        // Compress response if eligible
        // Set Content-Encoding
    }
}
````

#### 4. Favicon Plug
```swift
struct Favicon: ModulePlug {
    let iconData: Data
    let iconPath: String

    func call(_ conn: Connection) async throws -> Connection {
        // Serve favicon.ico
        // Return 404 for other paths
    }
}
````

#### 5. RateLimit Plug (Enhanced)
```swift
struct RateLimiter: ModulePlug {
    struct Options {
        let maxRequests: Int
        let windowSeconds: Int
        let identifier: (Connection) -> String
    }

    let options: Options
    let store: RateLimitStore

    func call(_ conn: Connection) async throws -> Connection {
        // Use external store for distributed systems
    }
}
````

## Acceptance Criteria

### ContentNegotiation
- [ ] Checks Accept header against supported types
- [ ] Returns 406 Not Acceptable if no match
- [ ] Sets Content-Type on response
- [ ] Supports quality values (q-values)

### Timeout
- [ ] Configurable timeout duration
- [ ] Returns 503 Service Unavailable on timeout
- [ ] Does not terminate underlying operation
- [ ] Works with async plugs

### Compression
- [ ] Checks Accept-Encoding header
- [ ] Compresses response body if eligible
- [ ] Sets Content-Encoding header
- [ ] Respects Content-Type filtering

### Favicon
- [ ] Serves static favicon from data
- [ ] Returns 404 for non-favicon paths
- [ ] Sets appropriate headers

### RateLimiter
- [ ] Uses configurable identifier function
- [ ] Supports external store (Redis, etc.)
- [ ] Returns 429 Too Many Requests when limited
- [ ] Includes rate limit headers in response

### Integration
- [ ] All new plugs work with `pipeline(_:)`
- [ ] All new plugs work with `pipe(_:_:)`
- [ ] All new plugs work with existing Nexus patterns
- [ ] No breaking changes to existing code

## Examples

### Content Negotiation
```swift
let negotiator = ContentNegotiation(
    supportedTypes: [.json, .html, .xml],
    defaultType: .html
)

// Request with Accept: application/json
// Response Content-Type: application/json

// Request with Accept: text/plain
// Response: 406 Not Acceptable
````

### Timeout
```swift
let timeout = Timeout(duration: .seconds(30))

let pipeline = pipeline([
    timeout,
    slowDatabaseQuery,
    renderTemplate
])
````

### Compression
```swift
let compression = Compression(
    algorithms: [.gzip, .brotli],
    minLength: 1024  // Only compress responses > 1KB
)

// Response body > 1KB → compressed
// Response body < 1KB → uncompressed
````

### Favicon
```swift
let faviconPlug = Favicon(
    iconData: faviconData,
    iconPath: "/favicon.ico"
)

// GET /favicon.ico → returns icon
// GET / → normal processing continues
````

### Rate Limiting
```swift
let rateLimiter = RateLimiter(
    options: .init(
        maxRequests: 100,
        windowSeconds: 60,
        identifier: { conn in
            conn[RemoteIPKey.self] ?? "unknown"
        }
    ),
    store: InMemoryRateLimitStore()
)

// Returns 429 when limit exceeded
// Includes X-RateLimit-* headers
````

## Implementation Notes

- Add new plug files to `Sources/Nexus/Plugs/`
- Each plug in its own file with clear naming
- Include comprehensive tests in `Tests/NexusTests/`
- Document each plug in README
- Consider feature flags for optional plugs
- Add to Package.swift if new dependencies needed
