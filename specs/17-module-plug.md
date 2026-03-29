# Spec 17: Module Plug Pattern

## Summary

Add support for module-based plugs (like Elixir's `Plug` behavior) in addition to the existing function plug pattern. This enables one-time configuration (validation, expensive setup) separate from per-request execution.

## Motivation

Module plugs allow:
- **Configuration phase**: Validate options, set up connections, pre-compute values once
- **Stateful behavior**: Store configuration in struct/enum between requests
- **Clean organization**: Related plug + options in one type

Current function plugs must capture all configuration in closures, making setup code run on every request or requiring external initialization.

## Design

Two forms of module plug:

### 1. Simple Module Plug
```swift
struct MyPlug: ModulePlug {
    let logger: Logger

    func call(_ connection: Connection) async throws -> Connection {
        // per-request logic
    }
}
```

### 2. Configurable Module Plug
```swift
struct SecurityHeaders: ConfigurableModulePlug {
    struct Options {
        let includeHSTS: Bool
        let includeCSP: Bool
    }

    let options: Options

    init(options: Options) throws {
        // validation happens once
        guard !options.includeHSTS || !options.includeCSP else {
            throw PlugError.invalidOptions
        }
    }

    func call(_ connection: Connection) async throws -> Connection {
        // per-request logic using self.options
    }
}
```

## Acceptance Criteria

### Configuration Phase
- [ ] `ModulePlug` has an optional `init(options:) throws` initializer
- [ ] If `init(options:)` is present, it is called **once** during plug construction
- [ ] If `init(options:)` is absent, plug is instantiated with no configuration
- [ ] Configuration errors are thrown during plug creation, not during request handling
- [ ] The `options` property (if present) is available in `call(_:)`

### Per-Request Phase
- [ ] `call(_:)` is called for each request with the configured instance
- [ ] Instance state is preserved between requests (configuration is reused)
- [ ] `call(_:)` may be async and throws
- [ ] The connection returned from `call(_:)` is used in the pipeline

### Integration with Existing Patterns
- [ ] Module plugs work with `pipe(_:_:)` and `pipeline(_:)`
- [ ] Module plugs can be converted to function plugs via `.asPlug()`
- [ ] Module plugs work with `rescueErrors(_:)`
- [ ] Module plugs work with `assign(key:value:)` pattern

### Backward Compatibility
- [ ] Existing function plugs continue to work unchanged
- [ ] `Plug` typealias remains unchanged
- [ ] No breaking changes to `ConfigurablePlug` protocol
- [ ] New protocol is additive only

## Examples

### Simple Module Plug
```swift
struct RequestLogging: ModulePlug {
    let logger: Logger

    func call(_ connection: Connection) async throws -> Connection {
        logger.info("Request: \(connection.request.method) \(connection.request.path ?? "/")")
        return connection
    }
}

// Usage
let plug = RequestLogging(logger: appLogger)
pipeline = pipeline(plugs: [plug, ...])
```

### Configurable Module Plug
```swift
struct RateLimiter: ConfigurableModulePlug {
    struct Options {
        let maxRequests: Int
        let windowSeconds: Int
    }

    let options: Options
    var requestCount: [String: Int] = [:]
    let lock = NSLock()

    init(options: Options) throws {
        guard options.maxRequests > 0 else {
            throw PlugError.invalidOptions("maxRequests must be positive")
        }
        guard options.windowSeconds > 0 else {
            throw PlugError.invalidOptions("windowSeconds must be positive")
        }
    }

    func call(_ connection: Connection) async throws -> Connection {
        let clientIP = connection[RemoteIPKey.self] ?? "unknown"

        lock.lock()
        defer { lock.unlock() }

        let now = Date().timeIntervalSince1970
        let windowStart = now - Double(options.windowSeconds)

        // Cleanup old entries
        requestCount = requestCount.filter { $0.value > windowStart }

        // Check limit
        let count = requestCount[clientIP] ?? 0
        guard count < options.maxRequests else {
            return connection
                .respond(status: .tooManyRequests)
                .halted()
        }

        requestCount[clientIP] = count + 1
        return connection
    }
}

// Usage
let plug = try RateLimiter(options: .init(maxRequests: 100, windowSeconds: 60))
```

### Migration from ConfigurablePlug
```swift
// Before (ConfigurablePlug)
struct OldStyle: ConfigurablePlug {
    let value: String
    init(options: String) { self.value = options }
    func call(_ conn: Connection) -> Connection { ... }
}

// After (ModulePlug)
struct NewStyle: ModulePlug {
    let value: String
    init(options: String) { self.value = options }
    func call(_ conn: Connection) async throws -> Connection { ... }
}

// Both work with pipeline(_:)
pipeline([OldStyle(options: "x"), NewStyle(options: "y")])
```

## Implementation Notes

- `ModulePlug` protocol in `Sources/Nexus/ModulePlug.swift`
- `ConfigurableModulePlug` protocol in `Sources/Nexus/ModulePlug.swift`
- Default `init(options:) throws` throws `PlugError.noConfiguration` if not implemented
- No `init()` required - use `init(options:)` with no parameters or optional
- The `call(_:)` method name matches Elixir's `call/2` signature
