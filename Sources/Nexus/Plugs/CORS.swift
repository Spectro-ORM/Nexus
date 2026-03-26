import HTTPTypes

/// Configuration for the CORS plug.
public struct CORSConfig: Sendable {

    /// Allowed origin(s). Use `"*"` for any origin.
    public var allowedOrigin: String

    /// Allowed HTTP methods.
    public var allowedMethods: [String]

    /// Allowed request headers.
    public var allowedHeaders: [String]

    /// Whether to include `Access-Control-Allow-Credentials`.
    public var allowCredentials: Bool

    /// Max age (in seconds) for preflight cache.
    public var maxAge: Int

    /// Creates a CORS configuration.
    ///
    /// - Parameters:
    ///   - allowedOrigin: The allowed origin. Defaults to `"*"`.
    ///   - allowedMethods: Allowed methods. Defaults to common REST methods.
    ///   - allowedHeaders: Allowed headers. Defaults to common headers.
    ///   - allowCredentials: Whether to allow credentials. Defaults to `false`.
    ///   - maxAge: Preflight cache duration in seconds. Defaults to 86400 (24h).
    public init(
        allowedOrigin: String = "*",
        allowedMethods: [String] = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        allowedHeaders: [String] = ["Content-Type", "Authorization", "Accept"],
        allowCredentials: Bool = false,
        maxAge: Int = 86400
    ) {
        self.allowedOrigin = allowedOrigin
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.allowCredentials = allowCredentials
        self.maxAge = maxAge
    }
}

/// A plug that adds CORS headers and handles OPTIONS preflight requests.
///
/// Applies `Access-Control-*` headers to every response. For OPTIONS
/// requests (preflight), it halts immediately with 204 No Content.
///
/// ```swift
/// let cors = corsPlug(CORSConfig(allowedOrigin: "https://example.com"))
/// let app = pipeline([cors, router])
/// ```
///
/// - Parameter config: The CORS configuration.
/// - Returns: A plug that handles CORS.
public func corsPlug(_ config: CORSConfig = CORSConfig()) -> Plug {
    { conn in
        var copy = conn
        copy.response.headerFields[HTTPField.Name("Access-Control-Allow-Origin")!] =
            config.allowedOrigin
        copy.response.headerFields[HTTPField.Name("Access-Control-Allow-Methods")!] =
            config.allowedMethods.joined(separator: ", ")
        copy.response.headerFields[HTTPField.Name("Access-Control-Allow-Headers")!] =
            config.allowedHeaders.joined(separator: ", ")

        if config.allowCredentials {
            copy.response.headerFields[HTTPField.Name("Access-Control-Allow-Credentials")!] = "true"
        }

        // Preflight: respond immediately with 204
        if conn.request.method == .options {
            copy.response.headerFields[HTTPField.Name("Access-Control-Max-Age")!] =
                "\(config.maxAge)"
            copy.response.status = .noContent
            copy.responseBody = .empty
            copy.isHalted = true
        }

        return copy
    }
}
