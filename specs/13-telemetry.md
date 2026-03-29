# Spec: Telemetry Plug

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** Nexus core (complete)

---

## 1. Goal

Production applications need observability — request duration, status code
distribution, error rates. Elixir's `Plug.Telemetry` emits `:telemetry`
events at request start and stop, which backends (Prometheus, StatsD,
DataDog) consume.

Swift has [`swift-metrics`](https://github.com/apple/swift-metrics) — an
API-only package (like `:telemetry`) where you plug in a backend at boot.
Nexus should emit metrics through `swift-metrics` so any backend works.

---

## 2. Scope

### 2.1 The Plug

```swift
// Sources/Nexus/Plugs/Telemetry.swift

/// Emits request metrics via swift-metrics.
///
/// Records:
/// - `nexus.request.duration` (Timer) — wall-clock time of the pipeline
/// - `nexus.request.count` (Counter) — incremented per request, labeled by status and method
///
/// ```swift
/// let app = pipeline([
///     telemetry(),
///     requestId(),
///     router,
/// ])
/// ```
public func telemetry(prefix: String = "nexus") -> Plug
```

### 2.2 Behavior

1. Capture `ContinuousClock.now` at plug entry.
2. Run the rest of the pipeline (pass through to downstream plugs).
3. After the pipeline returns (or throws), compute elapsed duration.
4. Emit a `Timer` measurement with label `<prefix>.request.duration`.
5. Emit a `Counter` increment with label `<prefix>.request.count`.
6. Attach dimensions: `method` (GET/POST/...) and `status` (200/404/500/...).

### 2.3 Error Handling

If a downstream plug throws:
- Still emit metrics (the request happened, it just failed).
- Set the status dimension to the thrown error's status if it's a
  `NexusHTTPError`, otherwise `500`.
- Re-throw the error after recording.

### 2.4 Dependency

This plug introduces a new dependency on `swift-metrics`. It should live
in the `Nexus` target (not a separate target) since metrics are a core
operational concern. The dependency is API-only — no backend is bundled.

---

## 3. Acceptance Criteria

- [ ] Timer metric emitted with request duration after each request
- [ ] Counter metric incremented per request
- [ ] Metrics include `method` dimension (e.g. "GET", "POST")
- [ ] Metrics include `status` dimension (e.g. "200", "404")
- [ ] Custom prefix: `telemetry(prefix: "myapp")` → `myapp.request.duration`
- [ ] Default prefix is `"nexus"`
- [ ] Thrown errors still emit metrics before re-throwing
- [ ] Thrown `NexusHTTPError` uses its status code; other errors use 500
- [ ] Duration is wall-clock time (uses `ContinuousClock` or `DispatchTime`)
- [ ] Composable in a pipeline with other plugs
- [ ] `swift test` passes (using `TestMetrics` from swift-metrics)

---

## 4. Non-goals

- No bundled metrics backend (Prometheus, StatsD, etc.).
- No per-route metrics breakdown (label by route pattern) — that requires
  router integration and is a follow-up.
- No distributed tracing / span propagation.
- No histogram/percentile support beyond what `Timer` provides.
