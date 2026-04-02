import Nexus

/// A reusable, named collection of plugs.
///
/// Create a pipeline once and apply it to multiple routes or scopes:
///
/// ```swift
/// let apiPipeline = NamedPipeline {
///     requestId()
///     auth
/// }
///
/// let router = Router {
///     scope("/api", through: apiPipeline) {
///         GET("/users") { conn in ... }
///     }
/// }
/// ```
public struct NamedPipeline: Sendable, ModulePlug {
    private let plugs: [Plug]

    /// Creates a pipeline from a result builder closure.
    ///
    /// - Parameter builder: A closure that returns the ordered list of plugs.
    public init(@PlugPipeline _ builder: () -> [Plug]) {
        self.plugs = builder()
    }

    /// Returns the composed pipeline as a single plug.
    public func asPlug() -> Plug {
        pipeline(plugs)
    }

    /// Processes a connection through the pipeline.
    /// Required for ModulePlug conformance.
    public func call(_ connection: Connection) async throws -> Connection {
        try await asPlug()(connection)
    }
}
