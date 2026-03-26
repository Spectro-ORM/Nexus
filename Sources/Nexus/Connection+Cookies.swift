import HTTPTypes

// MARK: - Request Cookies

extension Connection {

    /// Cookies parsed from the `Cookie` request header.
    ///
    /// Parses the semicolon-separated `name=value` pairs in the `Cookie`
    /// header. Values are returned as-is — no percent-decoding is applied
    /// because cookie values are opaque strings (RFC 6265 Section 4.2).
    ///
    /// For duplicate names the first value wins.
    ///
    /// Returns an empty dictionary when no `Cookie` header is present.
    public var reqCookies: [String: String] {
        guard let header = request.headerFields[.cookie] else {
            return [:]
        }
        var cookies: [String: String] = [:]
        for pair in header.split(separator: ";") {
            let trimmed = pair.drop(while: { $0 == " " })
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard let key = parts.first else { continue }
            let name = String(key)
            let value: String
            if parts.count > 1 {
                value = String(parts[1])
            } else {
                value = ""
            }
            if cookies[name] == nil {
                cookies[name] = value
            }
        }
        return cookies
    }
}

// MARK: - Response Cookies

extension Connection {

    /// Returns a copy with a `Set-Cookie` response header appended.
    ///
    /// Each call appends a new `Set-Cookie` field. Multiple cookies produce
    /// multiple headers, as required by RFC 6265 Section 4.1.
    ///
    /// - Parameter cookie: The cookie to set.
    /// - Returns: A new connection with the header appended.
    public func putRespCookie(_ cookie: Cookie) -> Connection {
        var copy = self
        copy.response.headerFields.append(
            HTTPField(name: .setCookie, value: cookie.headerValue)
        )
        return copy
    }

    /// Returns a copy with a `Set-Cookie` header that instructs the browser
    /// to delete the named cookie.
    ///
    /// Emits a `Set-Cookie` with an empty value and `Max-Age=0`, which causes
    /// compliant browsers to remove the cookie.
    ///
    /// - Parameters:
    ///   - name: The cookie name to delete.
    ///   - path: The path scope. Defaults to `"/"`.
    ///   - domain: The domain scope. Defaults to `nil`.
    /// - Returns: A new connection with the deletion header appended.
    public func deleteRespCookie(
        _ name: String,
        path: String = "/",
        domain: String? = nil
    ) -> Connection {
        let cookie = Cookie(
            name: name,
            value: "",
            path: path,
            domain: domain,
            maxAge: 0
        )
        return putRespCookie(cookie)
    }
}
