/// A function that handles an incoming WebSocket message.
///
/// Called once per message for the lifetime of the connection. The handler
/// receives the ``WSConnection`` (with its assigns and ``WSConnection/send``
/// function) and the incoming ``WSMessage``.
///
/// ```swift
/// let echo: WSHandler = { ws, message in
///     if case .text(let text) = message {
///         try await ws.send(.text("Echo: \(text)"))
///     }
/// }
/// ```
public typealias WSHandler = @Sendable (WSConnection, WSMessage) async throws -> Void

/// A function that inspects the HTTP ``Connection`` before a WebSocket
/// upgrade and produces the initial ``WSConnection``.
///
/// Throw from this handler to reject the upgrade (the server adapter will
/// return an appropriate HTTP error). Use it to authorize the upgrade,
/// extract path parameters, or propagate assigns from the HTTP pipeline.
///
/// ```swift
/// let connect: WSConnectHandler = { conn in
///     guard let token = conn.assigns["auth_token"] as? String else {
///         throw NexusHTTPError(.unauthorized)
///     }
///     return WSConnection(assigns: conn.assigns, send: { _ in })
/// }
/// ```
public typealias WSConnectHandler = @Sendable (Connection) async throws -> WSConnection
