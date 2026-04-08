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
    ///   - remoteIP: A simulated remote IP address. Defaults to `nil`.
    ///   - assigns: Optional dictionary of values to assign to the connection. Defaults to empty.
    /// - Returns: A fresh ``Connection`` ready for testing.
    public static func make(
        method: HTTPRequest.Method = .get,
        path: String = "/",
        headers: HTTPFields = [:],
        body: RequestBody = .empty,
        scheme: String = "https",
        authority: String = "example.com",
        remoteIP: String? = nil,
        assigns: [String: any Sendable] = [:]
    ) -> Connection {
        var connection = TestConnection.build(
            method: method,
            path: path,
            body: body,
            headers: headers,
            scheme: scheme,
            authority: authority,
            remoteIP: remoteIP
        )

        // Apply assigns if provided
        for (key, value) in assigns {
            connection = connection.assign(key: key, value: value)
        }

        return connection
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
    ///   - remoteIP: A simulated remote IP address. Defaults to `nil`.
    ///   - assigns: Optional dictionary of values to assign to the connection. Defaults to empty.
    /// - Returns: A ``Connection`` with the JSON body buffered.
    public static func makeJSON(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        json: String,
        scheme: String = "https",
        authority: String = "example.com",
        remoteIP: String? = nil,
        assigns: [String: any Sendable] = [:]
    ) -> Connection {
        var connection = TestConnection.buildJSON(
            method: method,
            path: path,
            json: json,
            scheme: scheme,
            authority: authority
        )

        // Apply remoteIP if provided
        if let remoteIP {
            connection = connection.assign(key: Connection.remoteIPKey, value: remoteIP)
        }

        // Apply assigns if provided
        for (key, value) in assigns {
            connection = connection.assign(key: key, value: value)
        }

        return connection
    }

    /// Creates a ``Connection`` with a JSON request body from an ``Encodable`` object.
    ///
    /// Sets the `Content-Type` header to `application/json` automatically.
    ///
    /// ```swift
    /// struct User: Codable {
    ///     let name: String
    ///     let email: String
    /// }
    ///
    /// let conn = Connection.makeJSON(
    ///     method: .post,
    ///     path: "/api/users",
    ///     body: User(name: "Alice", email: "alice@example.com")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.post`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - body: An ``Encodable`` object to serialize as JSON.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    ///   - remoteIP: A simulated remote IP address. Defaults to `nil`.
    ///   - assigns: Optional dictionary of values to assign to the connection. Defaults to empty.
    /// - Returns: A ``Connection`` with the JSON body buffered.
    /// - Throws: `EncodingError` if the body cannot be encoded as JSON.
    public static func makeJSON<T: Encodable>(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        body: T,
        scheme: String = "https",
        authority: String = "example.com",
        remoteIP: String? = nil,
        assigns: [String: any Sendable] = [:]
    ) throws -> Connection {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(body)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        var connection = TestConnection.buildJSON(
            method: method,
            path: path,
            json: jsonString,
            scheme: scheme,
            authority: authority
        )

        // Apply remoteIP if provided
        if let remoteIP {
            connection = connection.assign(key: Connection.remoteIPKey, value: remoteIP)
        }

        // Apply assigns if provided
        for (key, value) in assigns {
            connection = connection.assign(key: key, value: value)
        }

        return connection
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
    ///   - remoteIP: A simulated remote IP address. Defaults to `nil`.
    ///   - assigns: Optional dictionary of values to assign to the connection. Defaults to empty.
    /// - Returns: A ``Connection`` with the form body buffered.
    public static func makeForm(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        form: String,
        scheme: String = "https",
        authority: String = "example.com",
        remoteIP: String? = nil,
        assigns: [String: any Sendable] = [:]
    ) -> Connection {
        var connection = TestConnection.buildForm(
            method: method,
            path: path,
            form: form,
            scheme: scheme,
            authority: authority
        )

        // Apply remoteIP if provided
        if let remoteIP {
            connection = connection.assign(key: Connection.remoteIPKey, value: remoteIP)
        }

        // Apply assigns if provided
        for (key, value) in assigns {
            connection = connection.assign(key: key, value: value)
        }

        return connection
    }

    /// Creates a ``Connection`` with a URL-encoded form body from a dictionary.
    ///
    /// Sets the `Content-Type` header to `application/x-www-form-urlencoded`
    /// automatically and URL-encodes the field values.
    ///
    /// ```swift
    /// let conn = Connection.makeForm(
    ///     path: "/login",
    ///     fields: ["username": "alice", "password": "secret"]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.post`.
    ///   - path: The request path. Defaults to `"/"`.
    ///   - fields: A dictionary of form field names to values.
    ///   - scheme: The URL scheme. Defaults to `"https"`.
    ///   - authority: The host authority. Defaults to `"example.com"`.
    ///   - remoteIP: A simulated remote IP address. Defaults to `nil`.
    ///   - assigns: Optional dictionary of values to assign to the connection. Defaults to empty.
    /// - Returns: A ``Connection`` with the form body buffered.
    public static func makeForm(
        method: HTTPRequest.Method = .post,
        path: String = "/",
        fields: [String: String],
        scheme: String = "https",
        authority: String = "example.com",
        remoteIP: String? = nil,
        assigns: [String: any Sendable] = [:]
    ) -> Connection {
        let formString = fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")

        var connection = TestConnection.buildForm(
            method: method,
            path: path,
            form: formString,
            scheme: scheme,
            authority: authority
        )

        // Apply remoteIP if provided
        if let remoteIP {
            connection = connection.assign(key: Connection.remoteIPKey, value: remoteIP)
        }

        // Apply assigns if provided
        for (key, value) in assigns {
            connection = connection.assign(key: key, value: value)
        }

        return connection
    }
}
