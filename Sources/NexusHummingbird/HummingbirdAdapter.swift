import Nexus
import Hummingbird

/// Bridges a Nexus plug pipeline to Hummingbird's request handling layer.
///
/// `NexusHummingbirdAdapter` converts an incoming `Request` from Hummingbird
/// into a Nexus ``Connection``, runs it through a ``Plug`` pipeline, and
/// converts the resulting ``Connection`` back into a Hummingbird `Response`.
///
/// > Note: Full Hummingbird protocol conformance (`HTTPResponder`) is planned
/// > for Sprint 2. This type is the Sprint 0 scaffolding placeholder.
///
/// ## Example (Sprint 2 preview)
///
/// ```swift
/// let app = Application()
/// app.responder = NexusHummingbirdAdapter(plug: pipeline([
///     logger,
///     authPlug,
///     router.plug,
/// ]))
/// try await app.run()
/// ```
public struct NexusHummingbirdAdapter: Sendable {

    private let plug: Plug

    /// Creates an adapter that wraps the given plug pipeline.
    ///
    /// - Parameter plug: The root plug that handles every incoming request.
    public init(plug: @escaping Plug) {
        self.plug = plug
    }
}
