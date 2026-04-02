# SPEC-029: Named Pipeline

## Summary

Introduce `NamedPipeline` — a reusable, named collection of plugs that can be declared once and applied to multiple routes or scopes. This provides Phoenix-style pipeline composition while maintaining Nexus's Swift-first API.

## Motivation

Currently, Nexus supports:
- Global pipelines: `pipeline([...])` applies to all requests
- Scope-level middleware: `scope("/api", through: [auth])` applies plugs to route groups

What's missing is the ability to define reusable pipeline definitions that can be shared across multiple scopes without repeating the plug array. This leads to code duplication and makes it harder to maintain consistent middleware stacks.

## Proposed API

### Basic Usage

```swift
// Define a reusable pipeline
let apiPipeline = NamedPipeline {
    requestId()
    basicAuth { u, p in u == "admin" && p == "secret" }
    requireJSON
}

// Apply to multiple scopes
let router = Router {
    scope("/api/v1", through: apiPipeline) {
        GET("/users") { conn in ... }
    }

    scope("/api/v2", through: apiPipeline) {
        GET("/users") { conn in ... }
    }
}
```

### Integration with buildPipeline

```swift
let app = buildPipeline {
    requestLogger()
    apiPipeline  // NamedPipeline conforms to ModulePlug
    router
}
```

### Composition with Existing APIs

```swift
// Inline + NamedPipeline composition
let router = Router {
    scope("/api", through: [cors(), apiPipeline]) {
        GET("/public") { conn in ... }
    }
}
```

## Implementation

### NamedPipeline Struct

`NamedPipeline` conforms to `ModulePlug`, which means it works automatically with the existing `PlugPipeline` result builder via the `buildExpression(_ module: some ModulePlug)` method. No changes to `PlugPipeline` are required.

Note: An empty `NamedPipeline { }` behaves as an identity plug (passes through unchanged) since `pipeline([])` returns `{ conn in conn }`.

```swift
/// A reusable, named collection of plugs.
///
/// Create a pipeline once and apply it to multiple routes or scopes:
///
/// ```swift
/// let apiPipeline = NamedPipeline {
///     requestId()
///     auth
/// }
///
/// let router = Router {
///     scope("/api", through: apiPipeline) {
///         GET("/users") { conn in ... }
///     }
/// }
/// ```
public struct NamedPipeline: Sendable, ModulePlug {
    private let plugs: [Plug]

    /// Creates a pipeline from a result builder closure.
    ///
    /// - Parameter builder: A closure that returns the ordered list of plugs.
    public init(@PlugPipeline _ builder: () -> [Plug]) {
        self.plugs = builder()
    }

    /// Returns the composed pipeline as a single plug.
    public func asPlug() -> Plug {
        pipeline(plugs)
    }
}
```

### Router Integration

Add an overload to `scope(_:through:_:)` in `Scope.swift`:

```swift
/// Creates a group of routes that share a common path prefix and a
/// named middleware pipeline.
///
/// ```swift
/// let apiPipeline = NamedPipeline { requestId(); auth }
///
/// scope("/api", through: apiPipeline) {
///     GET("/users") { conn in ... }
/// }
/// ```
public func scope(
    _ prefix: String,
    through pipeline: NamedPipeline,
    @RouteBuilder _ routes: () -> [Route]
) -> [Route] {
    scope(prefix, through: [pipeline.asPlug()], routes)
}
```

## Test Plan

1. **Basic pipeline application**
   - Create NamedPipeline with multiple plugs
   - Apply via `scope(_:through:_:)`
   - Verify all plugs execute in order

2. **Reuse across scopes**
   - Apply same NamedPipeline to multiple scopes
   - Verify each scope gets the pipeline independently

3. **Integration with buildPipeline**
   - Use NamedPipeline directly inside `buildPipeline` closure (as a ModulePlug)
   - Verify it composes correctly with other plugs
   - Example: `buildPipeline { requestLogger(); apiPipeline; router }`

4. **Composition with inline plugs**
   - Mix NamedPipeline with inline `[Plug]` arrays
   - Verify correct execution order

5. **Halt handling**
   - Pipeline halts mid-way
   - Verify downstream plugs don't execute

6. **Empty pipeline**
   - Create NamedPipeline with no plugs
   - Verify it behaves as identity (passes through unchanged)

## Acceptance Criteria

- [ ] `NamedPipeline` struct exists with `@PlugPipeline` initializer
- [ ] Conforms to `Sendable` and `ModulePlug`
- [ ] `scope(_:through:_:)` overload accepting `NamedPipeline`
- [ ] Works with `buildPipeline` result builder
- [ ] All tests passing (target: 85%+ coverage)
- [ ] Documentation comments on all public symbols
- [ ] Example added to README.md

## Migration Path

No breaking changes. This is a purely additive feature that enhances existing `scope(_:through:_:)` with a new overload.

## References

- Inspired by Phoenix's `pipeline` and `pipe_through` macros
- Builds on existing `PlugPipeline` result builder (SPEC-026)
- Related: SPEC-021 (Plug Router), SPEC-026 (Plug Builder)
