import Foundation
import HTTPTypes
import Nexus

// MARK: - Connection.make() Factory

extension Connection {

    /// Creates a ``Connection`` for testing.
    ///
    /// A convenience alias for ``TestConnection/build(method:path:body:headers:scheme:authority:remoteIP:)``
    /// that places the factory method directly on ``Connection`` for ergonomic
    /// test syntax:
    ///
    /// ```swift
    /// let conn = Connection.make(method: .post, path: "/users")
    /// let result = try await myPlug(conn)
    /// #expect(result.response.status == .created)
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.get`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - headers: Request headers. Defaults to empty.
    ///   - body: The request body. Defaults to `.empty`.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    /// - Returns: A fresh ``Connection`` ready for testing.
    public static func make(
        method: HTTPRequest.Method = .get,
        path: String = "/",
        headers: HTTPFields = [:],
        body: RequestBody = .empty,
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        TestConnection.build(
            method: method,
            path: path,
            body: body,
            headers: headers,
            scheme: scheme,
            authority: authority
        )
    }

    /// Creates a ``Connection`` with a JSON request body for testing.
    ///
    /// Sets the `Content-Type` header to `application/json` automatically.
    ///
    /// ```swift
    /// let conn = Connection.makeJSON(
    ///     method: .post,
    ///     path: "/users",
    ///     json: #"{"name":"Alice"}"#
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.post`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - json: A JSON string to use as the request body.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    /// - Returns: A ``Connection`` with the JSON body buffered.
    public static func makeJSON(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        json: String,
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        TestConnection.buildJSON(
            method: method,
            path: path,
            json: json,
            scheme: scheme,
            authority: authority
        )
    }

    /// Creates a ``Connection`` with a URL-encoded form body for testing.
    ///
    /// Sets the `Content-Type` header to `application/x-www-form-urlencoded`
    /// automatically.
    ///
    /// ```swift
    /// let conn = Connection.makeForm(path: "/login", form: "user=alice&pass=secret")
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.post`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - form: A URL-encoded form string (e.g., `"name=Alice&age=30"`).
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    /// - Returns: A ``Connection`` with the form body buffered.
    public static func makeForm(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        form: String,
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        TestConnection.buildForm(
            method: method,
            path: path,
            form: form,
            scheme: scheme,
            authority: authority
        )
    }
}
