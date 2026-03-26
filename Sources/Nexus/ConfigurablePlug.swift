/// A plug with a distinct configuration phase.
///
/// Conforming types separate one-time option validation (``init(options:)``)
/// from per-request execution (``call(_:)``). The framework calls `init`
/// once at pipeline assembly time and `call` on every request.
///
/// This enables expensive setup (regex compilation, option validation, key
/// derivation) to happen once, and surfaces configuration errors eagerly at
/// boot rather than on the first request.
///
/// ## Example
///
/// ```swift
/// struct SecurityHeaders: ConfigurablePlug {
///     let includeHSTS: Bool
///
///     init(options: Bool) {
///         self.includeHSTS = options
///     }
///
///     func call(_ connection: Connection) async throws -> Connection {
///         var conn = connection
///         conn.response.headerFields[.xContentTypeOptions] = "nosniff"
///         if includeHSTS {
///             conn.response.headerFields[.strictTransportSecurity] = "max-age=31536000"
///         }
///         return conn
///     }
/// }
///
/// let securityPlug = try SecurityHeaders(options: true).asPlug()
/// let app = pipeline([securityPlug, router])
/// ```
///
/// ## Bridging
///
/// Use ``asPlug()`` to convert a configured instance into the universal
/// ``Plug`` closure type for use in `pipe`, `pipeline`, or the router DSL.
public protocol ConfigurablePlug: Sendable {

    /// The type of options this plug accepts.
    associatedtype Options: Sendable

    /// Validates and transforms raw options into the form used at runtime.
    ///
    /// Called once when the pipeline is assembled. Throw here to surface
    /// configuration errors eagerly.
    ///
    /// - Parameter options: The caller-supplied configuration.
    /// - Throws: If the options are invalid.
    init(options: Options) throws

    /// Processes a connection using the pre-validated configuration.
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The transformed connection.
    /// - Throws: Infrastructure errors only (see ADR-004).
    func call(_ connection: Connection) async throws -> Connection
}

extension ConfigurablePlug {

    /// Returns a ``Plug`` closure that calls this configurable plug's
    /// ``call(_:)`` method.
    ///
    /// - Returns: A plug suitable for use in `pipe`, `pipeline`, or the
    ///   router DSL.
    public func asPlug() -> Plug {
        { connection in
            try await self.call(connection)
        }
    }
}
