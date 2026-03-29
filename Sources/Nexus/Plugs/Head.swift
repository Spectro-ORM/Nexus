import HTTPTypes

/// Converts HEAD requests to GET so that existing GET routes handle them,
/// then strips the response body.
///
/// Per RFC 9110 §9.3.2, a server MUST respond to HEAD identically to GET
/// except it MUST NOT return a body. This plug rewrites HEAD to GET before
/// routing, and registers a ``Connection/registerBeforeSend(_:)`` callback
/// to strip the response body while preserving headers like `Content-Length`.
///
/// Place this early in the pipeline, before the router:
///
/// ```swift
/// let app = pipeline([
///     head(),
///     requestId(),
///     router,
/// ])
/// ```
///
/// - Returns: A plug that handles HEAD-to-GET conversion.
public func head() -> Plug {
    { conn in
        guard conn.request.method == .head else { return conn }

        var copy = conn
        copy.request.method = .get
        return copy.registerBeforeSend { conn in
            var conn = conn
            conn.responseBody = .empty
            return conn
        }
    }
}
