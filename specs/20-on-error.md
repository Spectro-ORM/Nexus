# Spec 20: on_error Plug

## Summary

Add `on_error/2` plug functionality for centralized error handling within the pipeline, matching Elixir's `Plug.ErrorHandler` behavior.

## Motivation

Currently, error handling in Nexus uses `rescueErrors(_:)` wrapper:
```swift
// Current pattern
let pipeline = pipeline([
    rescueErrors(myPlug),  // Wrap each plug individually
    ...
])
```

This requires wrapping each plug. Elixir's approach:
```elixir
# Centralized error handler
plug :fetch_errors
plug :do_something
plug :handle_errors

def handle_errors(conn, _opts) do
  # Centralized error page
end
````

Need a way to define a single error handler for the entire pipeline or section.

## Design

### Error Handler Plug
An error handler is a plug that:
1. Catches errors from downstream plugs
2. Can inspect the error and connection
3. Returns a halted connection with appropriate response

### Implementation Pattern
```swift
struct ErrorHandler: ModulePlug {
    let handler: (Connection, Error) -> Connection

    func call(_ connection: Connection) async throws -> Connection {
        // Try to execute the rest of the pipeline
        // On error, call handler and return halted conn
    }
}
```

### API Options

**Option A: Pipeline-level error handler**
```swift
func pipeline(_ plugs: [Plug], onError handler: @escaping (Connection, Error) -> Connection) -> Plug
```

**Option B: Plug wrapper with continuation**
```swift
func onError(_ handler: @escaping (Connection, Error) -> Connection) -> Plug
````

**Option C: Error context in Connection**
```swift
struct Connection {
    var error: Error?  // Populated if error occurred
}

func onError(_ handler: @escaping (Connection) -> Connection) -> Plug
```

## Acceptance Criteria

### Error Handler Registration
- [ ] `onError(_:)` creates a plug that catches errors from downstream
- [ ] Error handler receives both `Connection` and `Error` parameters
- [ ] Error handler returns a halted connection with appropriate response
- [ ] Only errors from downstream plugs are caught (not upstream)

### Error Propagation
- [ ] Errors from plugs before `onError` are not caught
- [ ] Errors from plugs after `onError` are caught
- [ ] Multiple `onError` handlers nest correctly (innermost wins)
- [ ] Non-Nexus errors propagate as infrastructure failures

### Connection State
- [ ] Connection passed to error handler reflects state at error point
- [ ] Error handler can read connection assigns, headers, etc.
- [ ] Error handler can modify connection before returning halted state

### Backward Compatibility
- [ ] Existing `rescueErrors(_:)` continues to work
- [ ] No breaking changes to error handling behavior
- [ ] New error handler is opt-in via `onError(_:)`

## Examples

### Basic Error Handler
```swift
func errorHandler(_ conn: Connection, _ error: Error) -> Connection {
    switch error {
    case is NexusHTTPError:
        return conn
            .respond(status: error.httpStatus)
            .halted()

    case let databaseError as DatabaseError:
        return conn
            .respond(status: .internalServerError)
            .setBody("Database error: \(error.localizedDescription)")
            .halted()

    default:
        return conn
            .respond(status: .internalServerError)
            .setBody("Internal server error")
            .halted()
    }
}

let pipeline = pipeline([
    errorHandler,
    authPlug,
    bodyParser,
    myHandler
])
```

### Handler with Config
```swift
struct ErrorHandler: ConfigurableModulePlug {
    struct Options {
        let showDebugInfo: Bool
    }

    let options: Options

    func call(_ connection: Connection, _ error: Error) async throws -> Connection {
        let errorId = UUID().uuidString

        if options.showDebugInfo {
            return conn
                .respond(status: .internalServerError)
                .setBody("Error \(errorId): \(error.localizedDescription)")
                .halted()
        } else {
            return conn
                .respond(status: .internalServerError)
                .setBody("Internal server error")
                .halted()
        }
    }
}

// Usage
let errorPlug = try ErrorHandler(options: .init(showDebugInfo: debugMode))
let pipeline = pipeline([errorPlug, ...])
```

### Handler with Context
```swift
let errorHandler = { conn, error in
    // Log the error
    appLogger.error("Request failed: \(error)")

    // Include request ID in error response
    let requestId = conn[RequestIdKey.self] ?? "unknown"

    return conn
        .putRespHeader("X-Error-ID", requestId)
        .respond(status: .internalServerError)
        .setBody("An error occurred (ID: \(requestId))")
        .halted()
}

// Use with rescueErrors for per-plug handling too
let pipeline = pipeline([
    rescueErrors(authPlug),
    errorHandler,
    rescueErrors(bodyParser),
    myHandler
])
```

### Nested Error Handlers
```swift
// Outer handler for general errors
let generalHandler = { conn, error in
    conn
        .respond(status: .internalServerError)
        .setBody("Server error")
        .halted()
}

// Inner handler for database-specific errors
let dbHandler = { conn, error in
    guard error is DatabaseError else {
        throw error  // Re-throw if not database error
    }
    conn
        .respond(status: .serviceUnavailable)
        .setBody("Database unavailable")
        .halted()
}

let pipeline = pipeline([
    generalHandler,
    dbHandler,
    ...
])
```

## Implementation Notes

- Add `onError(_:)` function to `Sources/Nexus/Plug.swift`
- Error handler is a separate plug type or uses existing `Plug` typealias
- Consider adding error context to `Connection` for cleaner API
- Test error handler with async throws plugs
- Ensure handler runs even if plug throws in middle of async chain
