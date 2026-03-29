# Changelog

All notable changes to Nexus are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.2.0]: https://github.com/Spectro-ORM/Nexus/compare/1.1.1...1.2.0
[1.1.0]: https://github.com/Spectro-ORM/Nexus/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/Spectro-ORM/Nexus/releases/tag/1.0.0
