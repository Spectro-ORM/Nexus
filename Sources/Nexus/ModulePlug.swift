/// A named plug type that holds configuration as properties and processes
/// connections per-request via ``call(_:)``.
///
/// `ModulePlug` is the lighter-weight companion to ``ConfigurablePlug``. Use
/// it when your plug carries its configuration as plain init parameters rather
/// than through a single `Options` struct. Configuration is captured once at
/// creation time; ``call(_:)`` is invoked on every request.
///
/// ```swift
/// struct SecurityHeaders: ModulePlug {
///     let includeHSTS: Bool
///
///     func call(_ connection: Connection) async throws -> Connection {
///         var conn = connection
///             .putRespHeader(.xContentTypeOptions, "nosniff")
///             .putRespHeader(.xFrameOptions, "DENY")
///         if includeHSTS {
///             conn = conn.putRespHeader(.strictTransportSecurity, "max-age=31536000")
///         }
///         return conn
///     }
/// }
///
/// let headers = SecurityHeaders(includeHSTS: true)
/// let app = pipeline([headers.asPlug(), router])
/// ```
public protocol ModulePlug: Sendable {

    /// Processes a connection during request handling.
    ///
    /// Called once per request. Perform per-request logic here and return a
    /// (possibly modified) connection. To terminate the pipeline without
    /// throwing, return `connection.halted()`. Throw only for infrastructure
    /// failures (see ADR-004).
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The transformed connection.
    /// - Throws: Infrastructure errors only (see ADR-004).
    func call(_ connection: Connection) async throws -> Connection
}

extension ModulePlug {

    /// Returns a ``Plug`` closure that delegates to this module plug's
    /// ``call(_:)`` method.
    ///
    /// Use `asPlug()` to convert a configured instance into the universal
    /// ``Plug`` function type for use in `pipe`, `pipeline`, or the router DSL.
    ///
    /// - Returns: A ``Plug`` suitable for use in `pipe`, `pipeline`, or the
    ///   router DSL.
    public func asPlug() -> Plug {
        { connection in try await self.call(connection) }
    }
}
