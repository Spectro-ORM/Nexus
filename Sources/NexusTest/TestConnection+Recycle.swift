import Foundation
import HTTPTypes
import Nexus

extension TestConnection {

    /// Creates a new test connection that carries forward cookies from a
    /// previous response, simulating a browser's cookie jar.
    ///
    /// Parses `Set-Cookie` response headers from the previous connection
    /// and injects them as a `Cookie` request header on the new connection.
    /// Cookies with `Max-Age=0` are excluded (deleted cookies).
    ///
    /// ```swift
    /// // Login
    /// let loginConn = try await app(TestConnection.build(
    ///     method: .post, path: "/login",
    ///     body: .buffered(Data("user=admin&pass=secret".utf8))
    /// ))
    ///
    /// // Authenticated request with cookies carried forward
    /// let conn = try await app(TestConnection.recycle(loginConn, path: "/dashboard"))
    /// ```
    ///
    /// - Parameters:
    ///   - previous: The connection whose response cookies should be recycled.
    ///   - method: The HTTP method. Defaults to `.get`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - body: The request body. Defaults to `.empty`.
    ///   - headers: Request headers. Defaults to empty.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    /// - Returns: A fresh connection with recycled cookies.
    public static func recycle(
        _ previous: Connection,
        method: HTTPRequest.Method = .get,
        path: String = "/",
        body: RequestBody = .empty,
        headers: HTTPFields = [:],
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        var recycledCookies: [String: String] = [:]

        for field in previous.response.headerFields {
            guard field.name == .setCookie else { continue }
            guard let parsed = parseSetCookie(field.value) else { continue }

            if parsed.isDeleted {
                recycledCookies.removeValue(forKey: parsed.name)
            } else {
                recycledCookies[parsed.name] = parsed.value
            }
        }

        // Parse explicit Cookie header from caller (if any)
        var explicitCookies: [String: String] = [:]
        if let cookieHeader = headers[.cookie] {
            for pair in cookieHeader.split(separator: ";") {
                let trimmed = pair.drop(while: { $0 == " " })
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                guard let key = parts.first else { continue }
                let name = String(key)
                let value = parts.count > 1 ? String(parts[1]) : ""
                explicitCookies[name] = value
            }
        }

        // Merge: explicit cookies override recycled ones
        let merged = recycledCookies.merging(explicitCookies) { _, explicit in explicit }

        // Build headers without the explicit Cookie (we set the merged one)
        var finalHeaders = headers
        finalHeaders[.cookie] = nil

        if !merged.isEmpty {
            let cookieString = merged
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "; ")
            finalHeaders[.cookie] = cookieString
        }

        return build(
            method: method,
            path: path,
            body: body,
            headers: finalHeaders,
            scheme: scheme,
            authority: authority
        )
    }
}

// MARK: - Set-Cookie Parsing

/// Parses a `Set-Cookie` header value into name, value, and deletion flag.
private func parseSetCookie(
    _ header: String
) -> (name: String, value: String, isDeleted: Bool)? {
    let parts = header.split(separator: ";", maxSplits: 1)
    guard let nameValue = parts.first else { return nil }

    let nvParts = nameValue.split(separator: "=", maxSplits: 1)
    guard let nameSlice = nvParts.first else { return nil }

    let name = String(nameSlice).trimmingCharacters(in: .whitespaces)
    let value = nvParts.count > 1
        ? String(nvParts[1]).trimmingCharacters(in: .whitespaces)
        : ""

    var isDeleted = false
    if parts.count > 1 {
        let attrs = String(parts[1]).lowercased()
        if attrs.contains("max-age=0") {
            isDeleted = true
        }
    }

    return (name, value, isDeleted)
}
