import Nexus
import HTTPTypes

/// A result-builder-based HTTP router that dispatches incoming requests to
/// the appropriate ``Plug`` based on method and path.
///
/// > Note: Full result-builder DSL is planned for Sprint 1. This type serves
/// > as the scaffolding placeholder for the target.
///
/// ## Usage (Sprint 1 preview)
///
/// ```swift
/// let router = Router {
///     GET("/health") { conn in
///         conn.respond(status: .ok, body: .string("OK"))
///     }
///     POST("/users") { conn in
///         // …
///         return conn
///     }
/// }
/// ```
public struct Router: Sendable {

    private let plug: Plug

    /// Creates a router from a single root plug.
    ///
    /// - Parameter plug: The plug that handles all requests.
    public init(plug: @escaping Plug) {
        self.plug = plug
    }

    /// Runs the router's plug pipeline on the given connection.
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The connection after it has been processed by the pipeline.
    /// - Throws: Any infrastructure error thrown by a plug.
    public func handle(_ connection: Connection) async throws -> Connection {
        try await plug(connection)
    }
}
