import Foundation
import HTTPTypes
import Nexus

/// Convenience builders for constructing ``Connection`` values in tests.
///
/// Eliminates the boilerplate of creating `HTTPRequest` structs directly:
///
/// ```swift
/// // Before:
/// let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/users")
/// let conn = Connection(request: request)
///
/// // After:
/// let conn = TestConnection.build(path: "/users")
/// ```
public enum TestConnection {

    /// Builds a ``Connection`` for testing.
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.get`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - body: The request body. Defaults to `.empty`.
    ///   - headers: Request headers. Defaults to empty.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    ///   - remoteIP: A simulated remote IP address. Defaults to `nil`.
    /// - Returns: A fresh ``Connection`` ready for testing.
    public static func build(
        method: HTTPRequest.Method = .get,
        path: String = "/",
        body: RequestBody = .empty,
        headers: HTTPFields = [:],
        scheme: String = "https",
        authority: String = "example.com",
        remoteIP: String? = nil
    ) -> Connection {
        var request = HTTPRequest(
            method: method,
            scheme: scheme,
            authority: authority,
            path: path
        )
        request.headerFields = headers
        var connection = Connection(request: request, requestBody: body)
        if let remoteIP {
            connection = connection.assign(
                key: Connection.remoteIPKey,
                value: remoteIP
            )
        }
        return connection
    }

    /// Builds a ``Connection`` with a URL-encoded form body for testing.
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.post`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - form: A URL-encoded form string (e.g. `"name=Alice&age=30"`).
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    /// - Returns: A ``Connection`` with the form body buffered and
    ///   `Content-Type` set to `application/x-www-form-urlencoded`.
    public static func buildForm(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        form: String,
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        build(
            method: method,
            path: path,
            body: .buffered(Data(form.utf8)),
            headers: [.contentType: "application/x-www-form-urlencoded"],
            scheme: scheme,
            authority: authority
        )
    }

    /// Builds a ``Connection`` with a JSON request body for testing.
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.post`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - json: A JSON string to use as the request body.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    /// - Returns: A ``Connection`` with the JSON body buffered.
    public static func buildJSON(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        json: String,
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        build(
            method: method,
            path: path,
            body: .buffered(Data(json.utf8)),
            headers: [.contentType: "application/json"],
            scheme: scheme,
            authority: authority
        )
    }
}
