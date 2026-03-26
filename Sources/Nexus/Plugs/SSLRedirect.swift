import HTTPTypes

/// A plug that redirects HTTP requests to HTTPS.
///
/// Checks the request scheme — if it is not `"https"`, responds with
/// a 301 Moved Permanently redirect to the HTTPS equivalent URL.
///
/// ```swift
/// let app = pipeline([sslRedirect(), logger, router])
/// ```
///
/// - Parameter host: Override the host in the redirect URL. If `nil`,
///   uses the request's authority. Useful behind reverse proxies.
/// - Returns: A plug that enforces HTTPS.
public func sslRedirect(host: String? = nil) -> Plug {
    { conn in
        guard conn.request.scheme != "https" else {
            return conn
        }

        let targetHost = host ?? conn.request.authority ?? "localhost"
        let path = conn.request.path ?? "/"
        let location = "https://\(targetHost)\(path)"

        var copy = conn
        copy.response.status = .movedPermanently
        if let locationField = HTTPField.Name("Location") {
            copy.response.headerFields[locationField] = location
        }
        copy.responseBody = .empty
        copy.isHalted = true
        return copy
    }
}
