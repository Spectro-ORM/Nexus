import Foundation

/// A WebSocket connection that carries state from the HTTP upgrade and
/// provides a ``send`` function for writing messages back to the client.
///
/// `WSConnection` mirrors ``Connection``'s assigns pattern: upstream HTTP
/// plugs populate assigns during the upgrade handshake, and the WebSocket
/// handler reads them to access authentication state, request IDs, etc.
///
/// ```swift
/// // Inside a message handler
/// let userId = ws.assigns["user_id"] as? String
/// try await ws.send(.text("Hello \(userId ?? "anonymous")"))
/// ```
public struct WSConnection: Sendable {

    /// Key–value store carried over from the HTTP ``Connection/assigns``
    /// and/or set during the upgrade handler.
    public var assigns: [String: any Sendable]

    /// Sends a message to the connected WebSocket client.
    public let send: @Sendable (WSMessage) async throws -> Void

    /// Creates a WebSocket connection.
    ///
    /// - Parameters:
    ///   - assigns: Initial assigns, typically propagated from the HTTP
    ///     connection that initiated the upgrade.
    ///   - send: The function used to write messages to the client.
    public init(
        assigns: [String: any Sendable] = [:],
        send: @escaping @Sendable (WSMessage) async throws -> Void
    ) {
        self.assigns = assigns
        self.send = send
    }

    /// Returns a copy with the given key–value pair merged into ``assigns``.
    ///
    /// - Parameters:
    ///   - key: The string key.
    ///   - value: The `Sendable` value to store.
    /// - Returns: A new `WSConnection` with the updated assigns.
    public func assign(key: String, value: some Sendable) -> WSConnection {
        var newAssigns = assigns
        newAssigns[key] = value
        return WSConnection(assigns: newAssigns, send: send)
    }
}
