/// A function that transforms a ``Connection``.
///
/// Plugs are the fundamental building block of the Nexus pipeline. A plug
/// receives a `Connection`, performs some work (validation, authentication,
/// header injection, body parsing, response construction, …), and returns
/// a new `Connection`.
///
/// ## Contract
///
/// - **No mutation** — plugs return a new `Connection`; they do not mutate
///   their input.
/// - **Halt, don't throw HTTP errors** — to respond early (e.g. 401, 404),
///   build the response and return `connection.halted()`. Throwing is reserved
///   for infrastructure failures (I/O errors, database timeouts, etc.).
/// - **Sendable** — plugs cross concurrency boundaries and must be `@Sendable`.
///
/// ## Example
///
/// ```swift
/// let logger: Plug = { conn in
///     print("→ \(conn.request.method) \(conn.request.path ?? "/")")
///     return conn
/// }
/// ```
public typealias Plug = @Sendable (Connection) async throws -> Connection

// MARK: - Composition Helpers

/// Returns a plug that runs `first` followed by `second`, short-circuiting if
/// `first` halts the connection.
///
/// - Parameters:
///   - first: The upstream plug.
///   - second: The downstream plug, skipped when the connection is halted.
/// - Returns: A composed plug.
public func pipe(_ first: @escaping Plug, _ second: @escaping Plug) -> Plug {
    { conn in
        let next = try await first(conn)
        guard !next.isHalted else { return next }
        return try await second(next)
    }
}

/// Returns a plug that applies each plug in `plugs` in order, stopping early
/// if any plug halts the connection.
///
/// - Parameter plugs: An ordered list of plugs to compose.
/// - Returns: A single plug representing the full pipeline.
public func pipeline(_ plugs: [Plug]) -> Plug {
    let identity: Plug = { conn in conn }
    return plugs.reduce(identity, pipe)
}
