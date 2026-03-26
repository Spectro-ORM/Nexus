/// A value type for building `Set-Cookie` response headers.
///
/// Models the attributes defined by RFC 6265. Use ``headerValue`` to serialize
/// the cookie into the format expected by the `Set-Cookie` header.
///
/// ```swift
/// let cookie = Cookie(name: "session", value: "abc123", httpOnly: true, secure: true)
/// conn = conn.putRespCookie(cookie)
/// ```
public struct Cookie: Sendable {

    /// The cookie name.
    public var name: String

    /// The cookie value.
    public var value: String

    /// Limits the cookie to the given URL path.
    public var path: String?

    /// Limits the cookie to the given domain.
    public var domain: String?

    /// The maximum lifetime in seconds. A value of `0` instructs the browser
    /// to delete the cookie.
    public var maxAge: Int?

    /// An explicit expiry date string (e.g. `"Thu, 01 Jan 2099 00:00:00 GMT"`).
    ///
    /// Kept as a plain `String` to avoid coupling to `Foundation.Date`.
    public var expires: String?

    /// When `true`, the cookie is only sent over HTTPS connections.
    public var secure: Bool

    /// When `true`, the cookie is inaccessible to client-side JavaScript.
    public var httpOnly: Bool

    /// The `SameSite` attribute restricting when the cookie is sent.
    public var sameSite: SameSite?

    /// Values for the `SameSite` cookie attribute.
    public enum SameSite: String, Sendable {
        /// The cookie is only sent in first-party contexts.
        case strict = "Strict"
        /// The cookie is sent with top-level navigations from external sites.
        case lax = "Lax"
        /// The cookie is sent with all requests. Requires ``Cookie/secure``
        /// to be `true`.
        case none = "None"
    }

    /// Creates a cookie with the given name, value, and optional attributes.
    ///
    /// - Parameters:
    ///   - name: The cookie name.
    ///   - value: The cookie value.
    ///   - path: Limits the cookie to the given URL path. Defaults to `nil`.
    ///   - domain: Limits the cookie to the given domain. Defaults to `nil`.
    ///   - maxAge: Maximum lifetime in seconds. Defaults to `nil`.
    ///   - expires: Explicit expiry date string. Defaults to `nil`.
    ///   - secure: Whether the cookie requires HTTPS. Defaults to `false`.
    ///   - httpOnly: Whether to hide the cookie from JavaScript. Defaults to `false`.
    ///   - sameSite: The `SameSite` attribute. Defaults to `nil`.
    public init(
        name: String,
        value: String,
        path: String? = nil,
        domain: String? = nil,
        maxAge: Int? = nil,
        expires: String? = nil,
        secure: Bool = false,
        httpOnly: Bool = false,
        sameSite: SameSite? = nil
    ) {
        self.name = name
        self.value = value
        self.path = path
        self.domain = domain
        self.maxAge = maxAge
        self.expires = expires
        self.secure = secure
        self.httpOnly = httpOnly
        self.sameSite = sameSite
    }

    /// The serialized `Set-Cookie` header value.
    ///
    /// Produces the `name=value[; attribute]*` format defined by RFC 6265.
    public var headerValue: String {
        var parts = ["\(name)=\(value)"]
        if let path {
            parts.append("Path=\(path)")
        }
        if let domain {
            parts.append("Domain=\(domain)")
        }
        if let maxAge {
            parts.append("Max-Age=\(maxAge)")
        }
        if let expires {
            parts.append("Expires=\(expires)")
        }
        if secure {
            parts.append("Secure")
        }
        if httpOnly {
            parts.append("HttpOnly")
        }
        if let sameSite {
            parts.append("SameSite=\(sameSite.rawValue)")
        }
        return parts.joined(separator: "; ")
    }
}
