# Spec 22: Adapter Pattern

## Summary

Create an adapter pattern for Nexus that separates the Plug specification from the HTTP server implementation, matching Elixir's `Plug.Adapters.Cowboy` pattern.

## Motivation

Elixir's adapter pattern:
```elixir
# Define your plug
plug MyApp.Router

# Start server with adapter
Plug.Cowboy.http(MyApp.Router, [], port: 4000)
Plug.Cowboy.child_spec([plug: MyApp.Router, port: 4000])
````

Current Nexus needs:
```swift
// Nexus currently ties to Hummingbird
let app = NexusApp()
app.use(plugs)
try app.run(port: 8080)
```

Need clean separation:
- **Plug layer**: Route and process requests
- **Adapter layer**: Bind to HTTP server, handle connection lifecycle
- **Server layer**: Start/stop HTTP server

## Design

### Adapter Protocol
```swift
protocol HTTPServerAdapter: Sendable {
    associatedtype Config: Sendable
    associatedtype Server: Sendable

    func start(plug: Plug, config: Config) throws -> Server
    func stop(server: Server) throws
    func getConfiguration(server: Server) -> Config
}
```

### Adapter Implementation
```swift
struct HummingbirdAdapter: HTTPServerAdapter {
    struct Config: Sendable {
        let host: String
        let port: Int
        let serverName: String?
    }

    func start(plug: Plug, config: Config) throws -> some HTTPServer {
        let hbApp = Application(config: .init())
        // Convert Nexus plug to Hummingbird handler
        hbApp.router.get("*") { request, context in
            // Convert request to Connection
            // Call plug
            // Convert response to Hummingbird response
        }
        return hbApp
    }

    func stop(server: some HTTPServer) throws {
        try server.wait()
    }
}
```

## Acceptance Criteria

### Adapter Protocol
- [ ] `HTTPServerAdapter` protocol defines `start(plug:config:)`
- [ ] `start(plug:config:)` returns a server instance
- [ ] `stop(server:)` shuts down the server
- [ ] Adapter is `Sendable` for concurrent use

### Server Abstraction
- [ ] Server instance can be started/stopped
- [ ] Server configuration is accessible
- [ ] Multiple adapters can target different servers

### Integration
- [ ] Adapter works with Nexus `Plug` typealias
- [ ] Adapter works with `pipeline(_:)`
- [ ] Adapter handles request/response conversion
- [ ] Adapter properly forwards errors

### Backward Compatibility
- [ ] Existing Hummingbird integration continues to work
- [ ] No breaking changes to current API
- [ ] New adapter API is opt-in

## Examples

### Basic Adapter Usage
```swift
// Define your app
let app: Plug = pipeline([
    RequestLogger(),
    bodyParser,
    myRouter
])

// Create adapter
let adapter = HummingbirdAdapter()

// Start server
let server = try adapter.start(
    plug: app,
    config: .init(host: "0.0.0.0", port: 8080, serverName: nil)
)

// Wait for server to stop
try adapter.stop(server: server)
```

### Multiple Adapters
```swift
// HTTP adapter
let httpAdapter = HummingbirdAdapter()
let httpServer = try httpAdapter.start(
    plug: app,
    config: .init(host: "0.0.0.0", port: 8080)
)

// HTTPS adapter (if supported)
let httpsAdapter = HummingbirdAdapter()
let httpsServer = try httpsAdapter.start(
    plug: app,
    config: .init(host: "0.0.0.0", port: 8443, ssl: true)
)
```

### Adapter with Config
```swift
struct ServerConfig: Sendable {
    let http: HummingbirdAdapter.Config
    let https: HummingbirdAdapter.Config?
    let gracefulShutdownTimeout: TimeAmount
}

struct NexusServer {
    let adapter: HTTPServerAdapter
    let config: ServerConfig

    func start(plug: Plug) throws {
        let server = try adapter.start(plug: plug, config: config.http)
        // Register shutdown handler
        // Handle graceful shutdown
    }

    func stop() throws {
        // Stop server with timeout
    }
}
```

### Custom Adapter
```swift
struct MyCustomAdapter: HTTPServerAdapter {
    struct Config: Sendable {
        let port: Int
    }

    func start(plug: Plug, config: Config) throws -> some HTTPServer {
        // Use any HTTP server library
        // Convert Nexus Connection to/from server's request/response types
        return CustomServer(port: config.port, handler: handleRequest)
    }

    private func handleRequest(_ request: CustomRequest) -> CustomResponse {
        // Convert to Nexus types
        let conn = Connection(request: .init(request))
        // Call plug
        let resultConn = plug(conn)
        // Convert back
        return CustomResponse(response: resultConn.response)
    }

    func stop(server: some HTTPServer) throws {
        server.shutdown()
    }
}
```

## Implementation Notes

- Create `Sources/Nexus/Adapters/` directory
- Adapter protocol in `Sources/Nexus/Adapters/HTTPServerAdapter.swift`
- Hummingbird adapter in `Sources/Nexus/Adapters/HummingbirdAdapter.swift`
- Consider supporting multiple server backends (NIO, async-http-client, etc.)
- Adapter should handle:
  - Request conversion (server types → `HTTPRequest`)
  - Response conversion (`HTTPResponse` → server types)
  - Error handling
  - Connection lifecycle (keep-alive, etc.)
