import HTTPTypes
import Metrics

/// Wraps a plug pipeline and emits request metrics via swift-metrics.
///
/// Records:
/// - `<prefix>.request.duration` (Timer) — wall-clock time of the pipeline
/// - `<prefix>.request.count` (Counter) — incremented per request
///
/// Both metrics include `method` and `status` dimensions.
///
/// This is a wrapper function (like ``rescueErrors(_:)``) because it needs
/// to measure the full pipeline duration, including error paths:
///
/// ```swift
/// let app = telemetry(pipeline([
///     requestId(),
///     router,
/// ]))
/// ```
///
/// - Parameters:
///   - plug: The plug or pipeline to wrap.
///   - prefix: Metric name prefix. Defaults to `"nexus"`.
/// - Returns: A plug that emits metrics around the wrapped pipeline.
public func telemetry(
    _ plug: @escaping Plug,
    prefix: String = "nexus"
) -> Plug {
    { conn in
        let start = ContinuousClock.now
        let method = conn.request.method.rawValue

        do {
            let result = try await plug(conn)
            emitMetrics(
                prefix: prefix,
                method: method,
                status: result.response.status.code,
                start: start
            )
            return result
        } catch let error as NexusHTTPError {
            emitMetrics(
                prefix: prefix,
                method: method,
                status: error.status.code,
                start: start
            )
            throw error
        } catch {
            emitMetrics(
                prefix: prefix,
                method: method,
                status: 500,
                start: start
            )
            throw error
        }
    }
}

private func emitMetrics(
    prefix: String,
    method: String,
    status: Int,
    start: ContinuousClock.Instant
) {
    let elapsed = ContinuousClock.now - start
    let (seconds, attoseconds) = elapsed.components
    let nanos = seconds * 1_000_000_000 + attoseconds / 1_000_000_000

    let dimensions = [("method", method), ("status", String(status))]

    Metrics.Timer(label: "\(prefix).request.duration", dimensions: dimensions)
        .recordNanoseconds(nanos)
    Counter(label: "\(prefix).request.count", dimensions: dimensions)
        .increment()
}
