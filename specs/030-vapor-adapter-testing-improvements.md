# Vapor Adapter and Testing Improvements Design

**Date:** 2026-04-08
**Status:** Approved
**Sprint:** 9A-9D (8 weeks)

## Executive Summary

Build a complete Vapor adapter for Nexus, proving full feature parity with the existing Hummingbird adapter through property-based testing. Simultaneously improve test coverage across all targets to 95%+, establishing Nexus as a truly server-agnostic HTTP middleware library for Swift.

## Goals

1. **Server Agnosticism** - Nexus works with Hummingbird AND Vapor, with zero coupling to either
2. **Parity Guarantees** - Property-based tests prove both adapters behave identically
3. **Coverage Excellence** - 95%+ test coverage across all targets
4. **Feature Parity** - WebSocket, SSE, streaming, error handling, lifecycle hooks

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────────┐          ┌──────────────────┐        │
│  │ Hummingbird App  │          │   Vapor App      │        │
│  └────────┬─────────┘          └────────┬─────────┘        │
└───────────┼──────────────────────────────┼─────────────────┘
            │                              │
            │ HTTPResponder                │ AsyncMiddleware
            │                              │
┌───────────┼──────────────────────────────┼─────────────────┐
│           │       Adapter Layer          │                 │
│  ┌────────▼─────────┐          ┌────────▼─────────┐       │
│  │ NexusHummingbird │          │  NexusVapor      │       │
│  │     Adapter      │          │     Adapter      │       │
│  └────────┬─────────┘          └────────┬─────────┘       │
└───────────┼──────────────────────────────┼─────────────────┘
            │                              │
            │    Convert to/from Connection │
            │                              │
┌───────────┼──────────────────────────────┼─────────────────┐
│           │       Nexus Core Layer       │                 │
│  ┌────────▼──────────────────────────────▼─────────┐       │
│  │         Plug Pipeline (server-agnostic)          │       │
│  │  logger → session → csrf → router → etc.        │       │
│  └─────────────────────────────────────────────────┘       │
│                                                             │
│  Core Types: Connection, Plug, RequestBody, ResponseBody   │
└─────────────────────────────────────────────────────────────┘
```

## Components

### NexusVapor Adapter

**File:** `Sources/NexusVapor/VaporAdapter.swift`

Implements Vapor's `AsyncMiddleware` protocol to bridge Nexus plug pipelines with Vapor applications.

**Key Features:**
- Converts `Vapor.Request` → `Nexus.Connection`
- Runs plug pipeline with ADR-004 error handling (infrastructure errors → 500)
- Runs beforeSend hooks per ADR-006 before response serialization
- Converts `Nexus.Connection` → `Vapor.Response`
- Populates `remoteIP` from Vapor's request context
- Supports request body collection up to configurable max size
- Supports response body streaming via `AsyncSequence`

**Usage:**
```swift
import Vapor
import Nexus
import NexusRouter
import NexusVapor

let router = Router()
router.get("hello") { conn in
    conn.respond(status: .ok, body: .string("Hello from Nexus!"))
}

let app = Application(.default)
app.middleware.use(
    NexusVaporAdapter(plug: router.handle),
    at: .root
)

try await app.execute()
```

### Vapor Request Context

**File:** `Sources/NexusVapor/VaporRequestContext.swift`

Vapor-specific request context for compatibility with Hummingbird adapter patterns. Vapor stores all request data on `Request` itself, so this is a thin wrapper.

### WebSocket Support

**File:** `Sources/NexusVapor/WebSocketAdapter.swift`

Extends `Vapor.Application` with `nexusWebSocket(routes:plug:)` method to register Nexus WebSocket routes.

**Key Features:**
- Registers WebSocket upgrade handler with Vapor
- Matches incoming WebSocket requests against `WSRoute` array
- Runs plug pipeline before upgrade (auth, sessions)
- Calls route's `connectHandler` to authorize upgrade
- Forwards WebSocket messages to route's `messageHandler`
- Closes connection on authorization failure

### SSE Support

**File:** `Sources/NexusVapor/SSEAdapter.swift`

Adds Server-Sent Events support to both adapters via `Connection.sseEvent(contentType:_:)` method.

**Key Features:**
- Streams `SSEEvent` objects to client
- Sets appropriate headers (`Content-Type: text/event-stream`, `Cache-Control: no-cache`)
- Leverages existing `SSEEvent` type from Nexus core
- Async/await streaming interface

## Testing Strategy

### Property-Based Testing with SwiftCheck

**File:** `Sources/NexusTest/HTTPGenerators.swift`

SwiftCheck generators for HTTP types:

```swift
// Generators for:
- HTTPRequest.Method (GET, POST, PUT, DELETE, etc.)
- HTTP headers (0-5 random headers)
- Request paths (random segment counts)
- Request bodies (empty or buffered data)
- Full HTTPRequest objects
```

**File:** `Tests/NexusTests/AdapterPropertyTests.swift`

Property tests proving adapter parity:

```swift
// Properties:
- Status codes match for all requests
- Response headers match for all requests
- Response bodies match for all requests
- Halted connections handled identically
- Errors (ADR-004) produce identical 500 responses
- BeforeSend hooks (ADR-006) run identically
- WebSocket authorization matches
- SSE stream content matches
```

**Execution:**
- 100-500 random test cases per property (configurable via `SWIFTCHECK_RUNS`)
- In-memory testing using Hummingbird/Vapor test frameworks
- Automatic shrinking finds minimal counterexamples
- Deterministic with seeded RNG for reproducible failures

### Coverage Improvements

**File:** `Sources/NexusTest/TestHelpers.swift`

Enhanced test utilities:

```swift
Connection.make(
    method: .post,
    path: "/test",
    headers: ["X-Custom": "value"],
    body: .buffered(data),
    remoteIP: "127.0.0.1",
    assigns: ["userId": "123"]
)

Connection.makeJSON(
    method: .post,
    path: "/api/users",
    body: User(name: "Alice")
)

Connection.makeForm(
    path: "/login",
    fields: ["username": "alice", "password": "secret"]
)
```

**Coverage Audit:**
- Manual audit of existing code to identify gaps
- Prioritize edge cases and error paths
- Fill gaps during implementation (not after)
- Ensure NexusVapor ships with 95%+ coverage from day one

**Expected Coverage Gaps:**
- Edge cases in Connection mutations
- Error paths in RequestBody/ResponseBody
- BeforeSend hook edge cases (double-invoke, errors)
- Public APIs without tests
- PathPattern matching edge cases
- Session crypto edge cases
- Static file edge cases (missing files, permissions)

## Work Breakdown

### Sprint 9A: Core Vapor Adapter + Basic Parity (2 weeks)

**Week 1:**
- Create `NexusVapor` target in Package.swift
- Implement `VaporAdapter.swift` with basic HTTP handling
- Implement `VaporRequestContext.swift`
- Add Vapor dependency to Package.swift
- Test basic GET/POST requests manually

**Week 2:**
- Implement SwiftCheck generators in `HTTPGenerators.swift`
- Implement property tests for status/header/body parity
- Run property tests to identify bugs
- Fix bugs until parity tests pass
- Coverage audit of existing code

**Deliverables:**
- ✅ Working Vapor adapter (GET, POST, headers, body)
- ✅ Property tests proving basic parity
- ✅ Coverage report with identified gaps

### Sprint 9B: Advanced Features + Full Parity (2 weeks)

**Week 3:**
- Implement ADR-004 error handling (infrastructure errors → 500)
- Implement ADR-006 BeforeSend hooks
- Add property tests for error handling
- Add property tests for BeforeSend hooks
- Fill high-priority coverage gaps

**Week 4:**
- Implement request body streaming
- Implement response body streaming
- Add property tests for streaming parity
- Fill remaining coverage gaps
- Verify 95%+ coverage for NexusVapor

**Deliverables:**
- ✅ Full ADR-004/ADR-006 compliance
- ✅ Streaming support in both adapters
- ✅ Property tests for advanced features
- ✅ 95%+ coverage across all targets

### Sprint 9C: WebSocket + SSE Support (2 weeks)

**Week 5:**
- Implement `WebSocketAdapter.swift` for Vapor
- Integrate with Vapor's WebSocket API
- Add WebSocket property tests
- Fix any WebSocket parity issues
- Document WebSocket usage

**Week 6:**
- Implement SSE support for both adapters
- Add SSE property tests
- Final coverage push to 95%+
- Performance benchmarking setup

**Deliverables:**
- ✅ WebSocket parity (Hummingbird === Vapor)
- ✅ SSE support in both adapters
- ✅ 95%+ test coverage achieved
- ✅ Performance benchmarks

### Sprint 9D: Polish + Release (2 weeks)

**Week 7:**
- DocC documentation for all public APIs
- Example code for common patterns
- Integration test suite (realistic app scenarios)
- Performance analysis and optimization

**Week 8:**
- Final bug fixes
- CHANGELOG.md update
- Version bump to 2.0.0
- Release preparation

**Deliverables:**
- ✅ Complete documentation
- ✅ Integration test suite
- ✅ Performance benchmarks
- ✅ Nexus 2.0.0 release

## Success Criteria

### Must Have (Block Release)

- ✅ Vapor adapter passes all property tests proving parity with Hummingbird
- ✅ 95%+ test coverage for NexusVapor target
- ✅ Zero breaking changes to Nexus core (existing tests pass)
- ✅ Full ADR-004 (error handling) and ADR-006 (lifecycle hooks) compliance
- ✅ Documentation for all public APIs

### Should Have (Stretch Goals)

- 🎯 WebSocket parity tests passing
- 🎯 SSE support in both adapters
- 🎯 Performance benchmarks showing <5% adapter overhead
- 🎯 Integration test suite demonstrating real-world usage

### Nice to Have (Future)

- 💭 Additional adapters (Express.js, Actix-web?)
- 💭 Adapter comparison guide in documentation
- 💭 Performance optimization based on benchmarks

## Risk Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Vapor API limitations | Medium | Medium | Use Hummingbird as golden master, adapt patterns |
| Property test complexity | Medium | Low | Start simple (status/headers), add complexity gradually |
| WebSocket testing differences | High | Medium | May need manual integration tests if property tests fail |
| CI build times | Low | Low | Run smaller sample size on PRs, full on main |
| Coverage gaps in existing code | Low | High | Already audited, prioritize during implementation |

## File Structure

```
Sources/
  Nexus/                          # Core (unchanged)
  NexusRouter/                   # Router DSL (unchanged)
  NexusHummingbird/              # Existing adapter (unchanged)
    ├── HummingbirdAdapter.swift
    ├── NexusRequestContext.swift
    └── WebSocketAdapter.swift
  NexusVapor/                    # NEW target
    ├── VaporAdapter.swift
    ├── VaporRequestContext.swift
    └── WebSocketAdapter.swift
  NexusTest/                     # Expanded test utilities
    ├── TestHelpers.swift        # Enhanced connection builders
    └── HTTPGenerators.swift     # SwiftCheck generators

Tests/
  NexusTests/
    ├── AdapterPropertyTests.swift  # NEW: Parity proofs
    ├── WebSocketPropertyTests.swift # NEW: WebSocket parity
    └── CoverageReportTests.swift   # NEW: Coverage tracking
```

## Definition of Done

Each feature is complete when:
- ✅ Code implements the design spec
- ✅ Property tests prove adapter parity
- ✅ Unit tests cover edge cases
- ✅ Coverage ≥95% for new code
- ✅ DocC comments on all public APIs
- ✅ Example usage in documentation
- ✅ All tests pass on macOS and Linux
- ✅ Code review approved

## Open Questions

None - design approved.

## References

- ADR-004: Error Handling (HTTP errors vs infrastructure failures)
- ADR-006: Plug Lifecycle Hooks (beforeSend callbacks)
- SwiftCheck: Property-based testing framework for Swift
- Vapor 4 Documentation: https://docs.vapor.codes/
- Hummingbird Documentation: https://hummingbird-docs.github.io/
