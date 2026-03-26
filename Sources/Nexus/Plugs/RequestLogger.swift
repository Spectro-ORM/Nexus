import Foundation
import HTTPTypes

/// A plug that logs HTTP request/response information.
///
/// Captures the request method and path on entry, then registers a
/// ``Connection/beforeSend`` callback that logs the final status code
/// and elapsed time.
///
/// ```swift
/// let app = pipeline([requestLogger(), authPlug, router])
/// ```
///
/// Output format: `GET /users → 200 OK (12ms)`
///
/// - Parameter logger: A closure that receives the formatted log line.
///   Defaults to `print`. Override for custom logging backends.
/// - Returns: A plug that logs request/response details.
public func requestLogger(
    _ logger: @escaping @Sendable (String) -> Void = { print($0) }
) -> Plug {
    { conn in
        let method = conn.request.method.rawValue
        let path = conn.request.path ?? "/"
        let start = ContinuousClock.now

        return conn.registerBeforeSend { c in
            let elapsed = ContinuousClock.now - start
            let ms = elapsed.components.attoseconds / 1_000_000_000_000_000
            let status = c.response.status.code
            logger("\(method) \(path) → \(status) (\(ms)ms)")
            return c
        }
    }
}
