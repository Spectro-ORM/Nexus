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
    /// - Returns: A fresh ``Connection`` ready for testing.
    public static func build(
        method: HTTPRequest.Method = .get,
        path: String = "/",
        body: RequestBody = .empty,
        headers: HTTPFields = [:],
        scheme: String = "https",
        authority: String = "example.com"
    ) -> Connection {
        var request = HTTPRequest(
            method: method,
            scheme: scheme,
            authority: authority,
            path: path
        )
        request.headerFields = headers
        return Connection(request: request, requestBody: body)
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
