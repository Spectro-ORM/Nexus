import HTTPTypes

/// An error representing an intentional HTTP response.
///
/// Throw this from a handler when you want to signal an HTTP error status
/// without manually building a halted response. The ``rescueErrors(_:)``
/// plug wrapper catches these and converts them to halted connections.
///
/// ```swift
/// GET("/users/:id") { conn in
///     guard let user = try await findUser(conn.params["id"]) else {
///         throw NexusHTTPError(.notFound, message: "User not found")
///     }
///     return try conn.json(value: user)
/// }
/// ```
public struct NexusHTTPError: Error, Sendable {

    /// The HTTP status code for the response.
    public let status: HTTPResponse.Status

    /// A human-readable error message included in the response body.
    public let message: String

    /// Creates an HTTP error with the given status and message.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code (e.g., `.notFound`, `.badRequest`).
    ///   - message: An optional message for the response body. Defaults to empty.
    public init(_ status: HTTPResponse.Status, message: String = "") {
        self.status = status
        self.message = message
    }
}

/// Wraps a plug (or pipeline) so that any ``NexusHTTPError`` thrown inside
/// is caught and converted to a halted response.
///
/// Non-`NexusHTTPError` errors pass through to the server adapter's
/// generic 500 handler, preserving the ADR-004 contract. Response headers
/// set by upstream middleware are preserved.
///
/// ```swift
/// let app = rescueErrors(pipeline([logger, auth, router]))
/// let adapter = NexusHummingbirdAdapter(plug: app)
/// ```
///
/// - Parameter plug: The plug or pipeline to wrap.
/// - Returns: A plug that catches `NexusHTTPError` and halts gracefully.
public func rescueErrors(_ plug: @escaping Plug) -> Plug {
    { conn in
        do {
            return try await plug(conn)
        } catch let error as NexusHTTPError {
            var copy = conn
            copy.response.status = error.status
            copy.responseBody = error.message.isEmpty
                ? .empty
                : .string(error.message)
            copy.isHalted = true
            return copy
        }
    }
}
