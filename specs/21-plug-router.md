# Spec 21: Plug.Router Integration

## Summary

Create a `Plug.Router` equivalent for Nexus that provides routing macros similar to Elixir's `Plug.Router`, integrated with the existing Nexus router layer.

## Motivation

Elixir's `Plug.Router` provides:
```elixir
defmodule MyApp.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/users" do
    send_resp(conn, 200, "Users")
  end

  get "/users/:id" do
    send_resp(conn, 200, "User #{id}")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
```

Nexus has a separate `NexusRouter` target but lacks:
- Elixir-style routing macros (`get/2`, `post/2`, `match/2`)
- Path parameters with named captures
- Pipe-like composition (`|> match |> dispatch`)
- Automatic path matching and dispatch

## Design

### Router Structure
```swift
struct AppRouter: Plug {
    func call(_ connection: Connection) async throws -> Connection {
        // Match path/method
        // Dispatch to handler
        // Return connection
    }
}
```

### Route Definition
```swift
enum Route {
    case get(String, Handler)
    case post(String, Handler)
    case put(String, Handler)
    case delete(String, Handler)
    case patch(String, Handler)
    case match(Handler)  // Default/fallback
}

typealias Handler = (Connection) async throws -> Connection
```

### Path Parameters
```swift
// Path with parameters
"/users/:id" matches "/users/123"
// Parameters: ["id": "123"]

// Wildcard parameters
"/files/*path" matches "/files/a/b/c"
// Parameters: ["*path": "a/b/c"]
```

## Acceptance Criteria

### Basic Routing
- [ ] `get(_:_:)` defines a GET route handler
- [ ] `post(_:_:)` defines a POST route handler
- [ ] `put(_:_:)` defines a PUT route handler
- [ ] `delete(_:_:)` defines a DELETE route handler
- [ ] `patch(_:_:)` defines a PATCH route handler
- [ ] `match(_:)` defines a fallback route handler

### Path Matching
- [ ] Exact path matching works
- [ ] Path parameters (`:id`) capture values
- [ ] Wildcard parameters (`*path`) capture remaining path
- [ ] Multiple routes are matched in order (first match wins)

### Route Dispatch
- [ ] Matching route handler is called with connection
- [ ] Handler can read path parameters from connection
- [ ] Handler returns a (potentially new) connection
- [ ] Unmatched routes return 404 or fall through

### Path Parameters
- [ ] `:param` syntax captures single path segment
- [ ] `*wildcard` syntax captures remaining path
- [ ] Parameters are accessible via `conn[.params]` or similar
- [ ] URL decoding is applied to captured parameters

### Error Handling
- [ ] Router handles malformed routes gracefully
- [ ] Router returns 404 for unmatched paths
- [ ] Router returns 405 for method not allowed (optional)
- [ ] Router errors can be caught by `rescueErrors(_:)`

### Integration
- [ ] Router works with `pipe(_:_:)` and `pipeline(_:)`
- [ ] Router works with other Nexus plugs
- [ ] Router integrates with Nexus `Connection` type
- [ ] Router can be used as a plug in another pipeline

## Examples

### Basic Router
```swift
struct AppRouter: Plug {
    private let routes: [Route]

    init() {
        routes = [
            get("/hello") { conn in
                conn
                    .putRespHeader("Content-Type", "text/plain")
                    .respond(status: .ok)
                    .setBody("Hello, World!")
            },
            get("/users/:id") { conn in
                let userId = conn[.params]["id"] ?? "unknown"
                conn
                    .respond(status: .ok)
                    .setBody("User: \(userId)")
            },
            match { conn in
                conn
                    .respond(status: .notFound)
                    .setBody("Not Found")
            }
        ]
    }

    func call(_ connection: Connection) async throws -> Connection {
        // Match route and dispatch
        for route in routes {
            if let handler = route.match(connection.request) {
                return try await handler(connection)
            }
        }
        return connection
            .respond(status: .notFound)
            .setBody("Not Found")
    }
}

// Usage
let router = AppRouter()
pipeline = pipeline([router])
```

### With Path Parameters
```swift
struct UserRouter: Plug {
    func call(_ connection: Connection) async throws -> Connection {
        switch (connection.request.method, connection.request.path) {
        case (.get, "/users"):
            return listUsers(connection)

        case (.get, let path) where path.hasPrefix("/users/"):
            let userId = extractUserId(from: path)
            return getUser(connection, userId: userId)

        case (.post, "/users"):
            return createUser(connection)

        default:
            return connection
                .respond(status: .notFound)
                .setBody("Not Found")
        }
    }

    private func extractUserId(from path: String) -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? "unknown"
    }
}
```

### With Parameter Extraction
```swift
// Helper to extract path parameters
extension Connection {
    var pathParameters: [String: String] {
        // Parse :param from route pattern
        // Extract values from actual path
        return [:]
    }
}

// Usage
get("/users/:id/posts/:postId") { conn in
    let userId = conn.pathParameters["id"] ?? "unknown"
    let postId = conn.pathParameters["postId"] ?? "unknown"
    // ...
}
```

### Nested Routers
```swift
struct ApiRouter: Plug {
    let userRouter: UserRouter
    let postRouter: PostRouter

    func call(_ connection: Connection) async throws -> Connection {
        if let path = connection.request.path, path.hasPrefix("/api/users") {
            return try await userRouter.call(connection)
        } else if let path = connection.request.path, path.hasPrefix("/api/posts") {
            return try await postRouter.call(connection)
        }
        return connection
            .respond(status: .notFound)
            .setBody("Not Found")
    }
}
```

## Implementation Notes

- Add to `Sources/NexusRouter/Router.swift` or new `Sources/Nexus/Router.swift`
- Consider using existing routing library (swift-nio-http-router, etc.)
- Path matching should be efficient (trie or regex-based)
- Support URL query parameters in addition to path parameters
- Consider adding `forward/2` for sub-routing (like Elixir)
