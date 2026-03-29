# Spec 26: Plug.Builder Macro

## Summary

Add a `Plug.Builder` pattern with Swift macros for declarative plug composition, matching Elixir's `use Plug.Builder` functionality.

## Motivation

Elixir's `Plug.Builder`:
```elixir
defmodule MyApp.Plug do
  use Plug.Builder

  plug Plug.Logger
  plug Plug.RequestId
  plug :auth
  plug :log_request

  def auth(conn, _opts) do
    # authentication logic
  end

  def log_request(conn, _opts) do
    # logging logic
  end
end
```

Current Nexus requires:
```swift
// Manual pipeline construction
let plugs: [Plug] = [
    requestLogger,
    requestIdPlug,
    authPlug,
    logRequestPlug
]
let app = pipeline(plugs)
````

Need:
- Declarative plug declarations
- Mix of module and function plugs
- Implicit `init/1` and `call/2` generation
- Plug ordering preserved

## Design

### Macro-Based Builder
```swift
@PlugBuilder
struct AppPlug {
    var logger: Logger

    func call(_ conn: Connection) async throws -> Connection {
        // Final plug in pipeline
    }
}
````

### Macro Expansion
```swift
// @PlugBuilder generates:
extension AppPlug: Plug {
    static func call(_ conn: Connection) async throws -> Connection {
        let plugs: [Plug] = [
            Self.loggerPlug(logger: self.logger),
            Self.requestIdPlug(),
            Self.authPlug(),
            Self.logRequestPlug(),
            Self.call(conn)  // The actual call method
        ]
        return await pipeline(plugs)(conn)
    }
}
````

### Function Plug Declaration
```swift
@PlugBuilder
struct MyApp {
    func call(_ conn: Connection) async throws -> Connection {
        // Main handler
    }

    @Plug
    func auth(_ conn: Connection) async throws -> Connection {
        // Authentication
    }

    @Plug(options: ["value": 42])
    func custom(_ conn: Connection) async throws -> Connection {
        // Custom logic
    }
}
````

## Acceptance Criteria

### Builder Macro
- [ ] `@PlugBuilder` macro generates plug from struct/class
- [ ] All `@Plug` methods are composed in order
- [ ] Final `call(_:)` method is the last plug in pipeline

### Plug Declaration
- [ ] `@Plug` marks a method as a plug
- [ ] `@Plug(options:)` passes options to plug
- [ ] Method parameters are captured for plug creation

### Order Preservation
- [ ] Plugs execute in declaration order
- [ ] `call(_:)` is always last in pipeline
- [ ] Plugin order is deterministic

### Integration
- [ ] Builder plugs work with `pipe(_:_:)`
- [ ] Builder plugs work with `pipeline(_:)`
- [ ] Builder plugs work with other Nexus plugs

### Error Handling
- [ ] Macro expansion errors are caught at compile time
- [ ] Runtime errors propagate normally
- [ ] No silent failures in macro expansion

## Examples

### Simple Builder
```swift
@PlugBuilder
struct AppPlug {
    let logger: Logger

    @Plug
    func requestId(_ conn: Connection) async throws -> Connection {
        let id = UUID().uuidString
        return conn.putRespHeader("X-Request-ID", id)
    }

    @Plug
    func auth(_ conn: Connection) async throws -> Connection {
        guard conn.getReqHeader("Authorization") != nil else {
            return conn.respond(status: .unauthorized).halted()
        }
        return conn
    }

    func call(_ conn: Connection) async throws -> Connection {
        return conn.setBody("Hello, World!")
    }
}

// Usage
let app = AppPlug(logger: myLogger)
// app is a valid Plug
````

### With Configuration
```swift
@PlugBuilder
struct SecureApp {
    @Plug(options: [ "maxBodySize": 1_000_000 ])
    func bodyParser(_ conn: Connection) async throws -> Connection {
        // With options
    }

    @Plug(options: [ "includeHSTS": true ])
    func securityHeaders(_ conn: Connection) async throws -> Connection {
        // With options
    }

    func call(_ conn: Connection) async throws -> Connection {
        return conn.setBody("Secure response")
    }
}
````

### Mixed Plugs
```swift
@PlugBuilder
struct MixedApp {
    @Plug
    let requestId = RequestIdPlug()  // Pre-built plug

    @Plug
    func logger(_ conn: Connection) async throws -> Connection {
        print("Request: \(conn.request.method) \(conn.request.path)")
        return conn
    }

    @Plug(options: [ "secret": "key" ])
    func session(_ conn: Connection) async throws -> Connection {
        // Session plug with config
    }

    func call(_ conn: Connection) async throws -> Connection {
        return conn.setBody("Mixed plugs work!")
    }
}
````

### Nested Builders
```swift
@PlugBuilder
struct APIPlug {
    @Plug
    func jsonBody(_ conn: Connection) async throws -> Connection {
        // Parse JSON
    }

    @Plug
    func validateJSON(_ conn: Connection) async throws -> Connection {
        // Validate JSON
    }

    func call(_ conn: Connection) async throws -> Connection {
        return conn.setBody("API handler")
    }
}

@PlugBuilder
struct AppPlug {
    @Plug
    let apiPlug = APIPlug()  // Nested builder as plug

    @Plug
    func log(_ conn: Connection) async throws -> Connection {
        print("Processing request")
        return conn
    }

    func call(_ conn: Connection) async throws -> Connection {
        return conn.setBody("App response")
    }
}
````

## Implementation Notes

- Use Swift 5.9+ macros (`@attached(peer)`, `@attached(accessory`)
- Macro generates `Plug` conformance and `call(_:)` implementation
- Track plug order via source order
- Support both function and module plugs
- Error messages should point to source location
- Consider supporting `init(options:)` for configuration
