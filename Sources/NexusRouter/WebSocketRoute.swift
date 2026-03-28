import Nexus

/// A WebSocket route that pairs a path pattern with upgrade and message
/// handlers.
///
/// Created via the ``WS(_:onUpgrade:onMessage:)`` builder function.
/// WebSocket routes are registered separately from HTTP routes and handled
/// by the server adapter's WebSocket upgrade mechanism.
public struct WSRoute: Sendable {

    /// The raw path pattern string (e.g., `"/ws/echo"`, `"/ws/:room"`).
    public let path: String

    /// The parsed path pattern used for matching.
    let pattern: PathPattern

    /// Called during the HTTP upgrade handshake to authorize the upgrade
    /// and produce the initial ``WSConnection``.
    public let connectHandler: WSConnectHandler

    /// Called for each message received on the WebSocket connection.
    public let messageHandler: WSHandler

    /// Creates a WebSocket route.
    ///
    /// - Parameters:
    ///   - path: The path pattern to match for WebSocket upgrades.
    ///   - connectHandler: The handler that runs during the upgrade handshake.
    ///   - messageHandler: The handler that processes incoming messages.
    public init(
        path: String,
        connectHandler: @escaping WSConnectHandler,
        messageHandler: @escaping WSHandler
    ) {
        self.path = path
        self.pattern = PathPattern(path)
        self.connectHandler = connectHandler
        self.messageHandler = messageHandler
    }

    /// Attempts to match the given request path against this route's pattern.
    ///
    /// - Parameter requestPath: The raw request path string.
    /// - Returns: A dictionary of extracted parameters if the path matches,
    ///   or `nil` if it does not.
    public func match(_ requestPath: String) -> [String: String]? {
        pattern.match(requestPath)
    }
}

/// Creates a WebSocket route that matches the given path.
///
/// The `onUpgrade` closure inspects the HTTP ``Connection`` (with all
/// assigns populated by upstream plugs) and returns a ``WSConnection``.
/// Throw to reject the upgrade.
///
/// The `onMessage` closure is called for each message received on the
/// established connection.
///
/// ```swift
/// WS("/ws/echo") { conn in
///     WSConnection(assigns: conn.assigns, send: { _ in })
/// } onMessage: { ws, message in
///     if case .text(let text) = message {
///         try await ws.send(.text("Echo: \(text)"))
///     }
/// }
/// ```
///
/// - Parameters:
///   - path: The path pattern to match for WebSocket upgrades.
///   - onUpgrade: Called during the upgrade handshake with the HTTP connection.
///   - onMessage: Called for each incoming WebSocket message.
/// - Returns: A ``WSRoute`` that can be registered with the server adapter.
public func WS(
    _ path: String,
    onUpgrade: @escaping WSConnectHandler,
    onMessage: @escaping WSHandler
) -> WSRoute {
    WSRoute(path: path, connectHandler: onUpgrade, messageHandler: onMessage)
}
