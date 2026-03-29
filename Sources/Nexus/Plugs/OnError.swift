/// Wraps a plug or pipeline with a centralized error handler.
///
/// When the wrapped plug throws any error, `handler` is invoked with the
/// connection state at the time of the error. The handler should return a
/// halted connection with an appropriate error response.
///
/// Unlike ``rescueErrors(_:)`` which only handles ``NexusHTTPError``,
/// `onError` catches **any** error thrown by the wrapped plug.
///
/// ```swift
/// let app = onError(pipeline([auth, bodyParser, router])) { conn, error in
///     await conn.respond(status: .internalServerError, body: .string("Server error"))
/// }
/// ```
///
/// ### Error Propagation
///
/// Only errors thrown by `plug` are caught. Errors that bubble up from
/// outside `plug` (e.g., from upstream middleware) are not affected.
///
/// ### Nested Handlers
///
/// `onError` composes naturally — inner handlers catch first:
///
/// ```swift
/// let dbHandler = onError(dbPlug) { conn, _ in
///     conn.respond(status: .serviceUnavailable, body: .string("DB unavailable"))
/// }
/// let app = onError(pipeline([dbHandler, router])) { conn, _ in
///     conn.respond(status: .internalServerError, body: .string("Server error"))
/// }
/// ```
///
/// - Parameters:
///   - plug: The plug or pipeline to protect.
///   - handler: Invoked when `plug` throws, receiving the connection at the
///     point of failure and the thrown error. Should return a halted connection.
/// - Returns: A plug that delegates to `handler` on any thrown error.
public func onError(
    _ plug: @escaping Plug,
    handler: @escaping @Sendable (Connection, Error) async throws -> Connection
) -> Plug {
    { conn in
        do {
            return try await plug(conn)
        } catch {
            return try await handler(conn, error)
        }
    }
}
