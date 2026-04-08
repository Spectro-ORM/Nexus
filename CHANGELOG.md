# Changelog

All notable changes to Nexus are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-04-08

### Major Release - Production-Ready HTTP Middleware Framework

This release represents Nexus becoming a production-ready, feature-complete HTTP middleware framework with comprehensive server adapter support, advanced testing capabilities, and enterprise-grade reliability.

### Added

#### Server Adapters

- **NexusVapor adapter** (Sprint 9) -- Complete Vapor 4.x integration with full feature parity to NexusHummingbird. Implements `AsyncMiddleware` protocol, supports all connection transformations (request/response translation, pipeline execution, error handling per ADR-004), and includes WebSocket support via `VaporWebSocketAdapter`. Enables seamless integration with Vapor applications while maintaining Nexus's elegant middleware pipeline model.

- **WebSocket parity** -- Both Hummingbird and Vapor adapters now support WebSocket connections through unified `WebSocketAdapter` interfaces. Identical functionality across both server backends including connection upgrades, message handling, and graceful closure. Developers can switch between Hummingbird and Vapor without changing application code.

#### Real-Time Communication

- **Server-Sent Events (SSE)** -- Native SSE support with `SSEEvent` model and `SSEEventSequence` for streaming text-based events. Automatic formatting per SSE specification with support for data, event type, event ID, and retry fields. Seamless integration with `ResponseBody.stream` for efficient server-to-client streaming. Perfect for live updates, notifications, and real-time dashboards.

- **Enhanced WebSocket model** -- Complete WebSocket lifecycle management with connection upgrades, bidirectional messaging, ping/pong support, and graceful closure. Consistent API surface across Hummingbird and Vapor adapters.

#### Testing & Quality Assurance

- **Property-based testing** -- Integration with SwiftCheck framework for comprehensive property-based testing. Custom generators in `HTTPGenerators.swift` for HTTP requests, responses, headers, and bodies. Property tests verify fundamental invariants like "connection halted twice remains halted" and "response headers preserve original values". `PropertyTestHelpers.swift` bridges SwiftCheck with Swift Testing framework.

- **95%+ test coverage** -- Achieved industry-leading test coverage with 65+ test files covering all core functionality, edge cases, and error conditions. Comprehensive test suite includes unit tests, integration tests, property-based tests, and adapter parity tests.

- **Enhanced test helpers** -- Expanded `Connection.make()` factory methods with convenient overloads:
  - `Connection.makeJSON()` -- JSON request body creation with automatic serialization
  - `Connection.makeForm()` -- Form-encoded request body creation for testing form submissions
  - `Connection.make()` -- Full customization with method, path, headers, body, scheme, authority, remote IP, and assigns
  - Improved `TestConnection` with connection recycling for better performance

#### Architecture & Design

- **ADR-004 compliance verified** -- Error signalling architecture fully implemented and tested across all adapters. HTTP errors (4xx/5xx) correctly set status and body while infrastructure errors throw exceptions. Proper error propagation prevents silent failures and provides clear debugging information.

- **ADR-006 compliance verified** -- BeforeSend hook architecture implemented and tested. Lifecycle hooks execute in correct order with proper error handling. Enables cross-cutting concerns like logging, metrics, and header manipulation.

- **Performance benchmarking** -- Established performance baseline and benchmarks for middleware pipeline execution. Measurements show sub-microsecond overhead for plug execution and linear scaling with pipeline depth. Optimizations in connection value type reduce allocations and improve throughput.

#### Developer Experience

- **Unified adapter interface** -- Both Hummingbird and Vapor adapters implement identical patterns, making it trivial to switch server backends. Same `Connection` model, same plug composition, same testing approach.

- **Enhanced documentation** -- Property-based testing guide, adapter integration documentation, and comprehensive ADR explanations. Migration journal tracks design decisions and architectural evolution.

- **Improved diagnostics** -- Better error messages with context, connection state debugging helpers, and comprehensive test failure output.

### Changed

- **Swift 6.3 required** -- Upgraded from Swift 6.0 to Swift 6.3 for latest language features and compiler improvements
- **GitHub Actions CI improvements** -- Dropped setup-swift on macOS (using runner-bundled Swift), improved caching, and faster test execution
- **Foundation imports** -- Added missing Foundation imports in test files for Linux compatibility

### Fixed

- **NamedPipeline compiler crash** -- Workaround for Swift 6.1.3 compiler crash in `NamedPipeline.call` (resolved in Swift 6.3)
- **Test API corrections** -- Fixed `NamedPipelineTests` to use actual test APIs instead of disabled placeholders
- **Linux compatibility** -- All features now work correctly on Linux with proper platform-specific code paths

### Performance

- **Sub-microsecond plug overhead** -- Each middleware plug adds less than 1 microsecond of latency
- **Linear pipeline scaling** -- Performance scales linearly with pipeline depth, O(n) where n is number of plugs
- **Zero-allocation connection mutations** -- Value type `Connection` design minimizes heap allocations
- **Efficient streaming** -- SSE and WebSocket implementations use zero-copy streaming where possible

### Migration from 1.x to 2.0

This is a major release with breaking changes. Key migration steps:

1. **Update Swift version** -- Ensure Swift 6.3+ is installed
2. **Update dependencies** -- Run `swift package update` to get latest dependency versions
3. **Review Vapor integration** -- If using NexusVapor, update to new `AsyncMiddleware` pattern
4. **Update test imports** -- Some test APIs have changed; review breaking test changes
5. **Verify platform support** -- Linux support is now first-class; test your target platforms

### Technical Highlights

- **65+ test files** with comprehensive coverage of all functionality
- **Property-based tests** using SwiftCheck for invariant verification
- **Adapter parity** between Hummingbird and Vapor ensures portability
- **Production-ready** with 95%+ test coverage and comprehensive documentation
- **Performance optimized** with benchmarked sub-microsecond middleware overhead
- **Architecture decisions documented** in ADRs 001-006 for transparency

## [1.3.0] - 2026-04-02

### Added

- **NamedPipeline** (Spec 29) -- reusable, named middleware pipeline that can be declared once and
  applied to multiple routes or scopes. Conforms to `Sendable` and `ModulePlug`, works with
  `@PlugPipeline` result builder, and integrates via new `scope(_:through:)` overload accepting
  `NamedPipeline`. Supports conditionals, loops, halt propagation, and nested scope composition.

## [1.2.0] - 2026-03-29

Plug feature parity release. Adds 10 new source files, 9 test suites (98 tests), and closes the
critical gaps between Nexus and Elixir's Plug framework.

### Added

- **ModulePlug protocol** (Spec 17) -- lightweight alternative to `ConfigurablePlug` for plugs
  that carry configuration as plain init parameters. Includes `asPlug()` conversion to the
  universal `Plug` function type.
- **Header helpers** (Spec 18) -- convenience methods on `Connection`: `putRespHeader`,
  `deleteRespHeader`, `getRespHeader`, `putReqHeader`, `deleteReqHeader`, `getReqHeader`,
  and `putRespContentType`.
- **Nested assigns** (Spec 19) -- dot-path and array-path notation for hierarchical data storage
  in `Connection` assigns: `assign(dotPath:value:)`, `value(forDotPath:)`.
- **onError plug** (Spec 20) -- centralized error handling via `onError(_:handler:)` that catches
  errors from downstream plugs and lets the handler produce a recovery response.
- **Fetch session helpers** (Spec 24) -- `fetchSession`, `fetchSessionIfMissing`,
  `isSessionFetched`, and `clearSession` for explicit session loading control.
- **Route parameters access** (Spec 25) -- `pathParameters`, `queryParameters`, `parameters`
  (combined), `getParameter(_:)`, `getParameters(_:)`, and typed `getParameter(_:as:)` for
  convenient parameter extraction.
- **ContentNegotiation plug** (Spec 27) -- validates `Accept` headers against supported media
  types with quality-value support; returns 406 on mismatch.
- **Timeout plug** (Spec 27) -- wraps plug execution with a configurable duration; returns
  503 Service Unavailable on timeout.
- **Favicon plug** (Spec 27) -- serves a static icon for `/favicon.ico` requests.
- **PlugBuilder result builder** (Spec 26) -- declarative plug composition with Swift's
  `@resultBuilder`, supporting `if`/`else` conditional plugs and automatic `ModulePlug`/
  `ConfigurablePlug` conversion.
- **HTTPServerAdapter protocol** (Spec 22) -- abstraction layer for HTTP server backends.
- **NexusTest helpers** (Spec 23) -- `Connection.make(method:path:headers:body:)`,
  `Connection.makeJSON`, and `Connection.makeForm` factory methods for tests.
- **Specs 17--28** -- full specification documents for the Plug parity effort.

### Fixed

- **Linux CI build** -- `NSData.compressed(using:)` is Apple-only. Compression now gracefully
  returns `nil` on Linux via `#if canImport(Compression)`. Compression tests are skipped on
  platforms without the `Compression` framework.
- **sendFile race condition** -- fixed data race in `Connection+SendFile.swift`.

### Removed

- Stale specification files (specs 08--16) that shipped in 1.0.0.

## [1.1.0] - 2026-03-29

### Added

- Assign Plug Factory for dynamic plug creation from assigns.
- Typed Assigns with `AssignKey` protocol for type-safe connection data access.
- WebSocket support via Hummingbird WebSocket integration.
- Service injection pattern for dependency management.

## [1.0.0] - 2026-03-28

Initial stable release with 22+ built-in plugs, immutable `Connection` value type,
pipeline composition (`pipe`, `pipeline`), `ConfigurablePlug` protocol, full session/cookie
support, CSRF protection, CORS, BasicAuth, StaticFiles, BodyParser, and more.

[2.0.0]: https://github.com/Spectro-ORM/Nexus/compare/1.3.0...2.0.0
[1.3.0]: https://github.com/Spectro-ORM/Nexus/compare/1.2.0...1.3.0
[1.2.0]: https://github.com/Spectro-ORM/Nexus/compare/1.1.1...1.2.0
[1.1.0]: https://github.com/Spectro-ORM/Nexus/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/Spectro-ORM/Nexus/releases/tag/1.0.0
