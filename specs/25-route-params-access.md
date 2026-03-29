# Spec 25: Route Parameters Access

## Summary

Add convenient access to route parameters from the Connection, matching Elixir's `conn.params` functionality.

## Motivation

Elixir's Plug.Router provides:
```elixir
get "/users/:id" do
  user_id = conn.params["id"]  # Path parameter
  format = conn.params["format"]  # Query parameter
  # ...
end
```

Current Nexus:
```swift
// No built-in way to access route parameters
// Must manually parse path
let components = path.components(separatedBy: "/")
```

Need:
- Path parameters from route patterns (`:id`, `*wildcard`)
- Query parameters
- Combined params for convenience

## Design

### Route Parameters in Connection
```swift
extension Connection {
    var pathParameters: [String: String] { get }
    var queryParameters: [String: [String]] { get }
    var parameters: [String: [String]] { get }  // Combined
}
```

### Parameter Types
```swift
// Single value (last one wins for duplicates)
func getParameter(_ name: String) -> String?

// Multiple values
func getParameters(_ name: String) -> [String]

// Typed parameter extraction
func getParameter<T: Decodable>(_ name: String, as: T.Type) -> T?
```

## Acceptance Criteria

### Path Parameters
- [ ] Path parameters (`:id`) are extracted from matched route
- [ ] Wildcard parameters (`*path`) capture remaining path
- [ ] Path parameters are URL-decoded
- [ ] Missing path parameters return nil/empty

### Query Parameters
- [ ] Query parameters are parsed from URI
- [ ] Multiple values for same key are preserved
- [ ] Query parameters are URL-decoded

### Combined Access
- [ ] `parameters` combines path and query params
- [ ] Path parameters take precedence over query params
- [ ] Query parameter arrays are preserved

### Type Conversion
- [ ] Typed parameter extraction supports common types
- [ ] Decodable types are supported
- [ ] Conversion errors are handled gracefully

### Integration
- [ ] Route parameters work with NexusRouter
- [ ] Route parameters work with custom routers
- [ ] Route parameters work with parameterized plugs

## Examples

### Path Parameters
```swift
// Route: /users/:id
// Request: GET /users/123

conn[.pathParameters]["id"]  // "123"
conn.pathParameters["id"]    // "123"
```

### Wildcard Parameters
```swift
// Route: /files/*path
// Request: GET /files/a/b/c

conn.pathParameters["*path"]  // "a/b/c"
```

### Query Parameters
```swift
// Request: GET /users?page=2&limit=10&sort=name

conn.queryParameters["page"]    // ["2"]
conn.queryParameters["sort"]    // ["name"]
conn.getParameter("page")       // "2"
```

### Combined Parameters
```swift
// Request: GET /users/:id?source=query&format=json
// Path: /users/123

conn.parameters["id"]      // ["123"] - from path
conn.parameters["source"]  // ["query"] - from query
conn.parameters["format"]  // ["json"] - from query
```

### Typed Parameters
```swift
// Request: GET /users?age=30&score=95.5

let age: Int = conn.getParameter("age", as: Int.self) ?? 0
let score: Double = conn.getParameter("score", as: Double.self) ?? 0.0
```

### In Router
```swift
get("/users/:id") { conn in
    let userId = conn.pathParameters["id"] ?? "unknown"
    return conn
        .respond(status: .ok)
        .setBody("User ID: \(userId)")
}

get("/posts/:year/:month/:day") { conn in
    let year = conn.pathParameters["year"] ?? ""
    let month = conn.pathParameters["month"] ?? ""
    let day = conn.pathParameters["day"] ?? ""
    return conn
        .respond(status: .ok)
        .setBody("Posts from \(year)-\(month)-\(day)")
}
````

## Implementation Notes

- Add `pathParameters`, `queryParameters`, `parameters` to `Connection`
- Path parameter extraction could be done by router or middleware
- Consider adding parameter extraction to `Router` type
- Handle URL decoding for all parameters
- Consider adding parameter validation helpers
