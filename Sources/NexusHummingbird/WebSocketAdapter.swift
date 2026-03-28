import Foundation
import Hummingbird
import HummingbirdCore
import HummingbirdWebSocket
import NIOCore
import NIOWebSocket
import Nexus
import NexusRouter
import WSCore

extension HTTPServerBuilder {

    /// Creates an HTTP/1.1 server builder that supports WebSocket upgrades
    /// for registered Nexus ``WSRoute``s.
    ///
    /// Non-WebSocket requests (and WebSocket requests that don't match any
    /// route) fall through to the regular HTTP responder provided by
    /// ``NexusHummingbirdAdapter``.
    ///
    /// ```swift
    /// let wsRoutes = [
    ///     WS("/ws/echo", onUpgrade: { conn in
    ///         WSConnection(assigns: conn.assigns, send: { _ in })
    ///     }, onMessage: { ws, msg in
    ///         if case .text(let t) = msg { try await ws.send(.text("Echo: \(t)")) }
    ///     }),
    /// ]
    /// let adapter = NexusHummingbirdAdapter(plug: myPipeline)
    /// let app = Application(
    ///     responder: adapter,
    ///     server: .nexusWebSocket(routes: wsRoutes)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - routes: The WebSocket routes to register.
    ///   - plug: An optional plug pipeline to run on the upgrade request
    ///     before invoking the route's ``WSConnectHandler``. Pass this to
    ///     let authentication, session, and request-ID plugs populate
    ///     ``Connection/assigns`` before the upgrade.
    ///   - configuration: WebSocket server configuration. Defaults to the
    ///     standard Hummingbird defaults.
    /// - Returns: An HTTP server builder suitable for ``Application/init``.
    public static func nexusWebSocket(
        routes: [WSRoute],
        plug: Plug? = nil,
        configuration: WebSocketServerConfiguration = .init()
    ) -> HTTPServerBuilder {
        .http1WebSocketUpgrade(
            configuration: configuration
        ) { (request: HTTPTypes.HTTPRequest, channel: any Channel, _) async throws
            -> ShouldUpgradeResult<WebSocketDataHandler<HTTP1WebSocketUpgradeChannel.Context>> in

            let path = request.path ?? "/"

            for route in routes {
                guard let params = route.match(path) else { continue }

                // Build a Nexus Connection from the upgrade request
                var conn = Connection(request: request)
                if let ip = channel.remoteAddress?.ipAddress {
                    conn = conn.assign(key: Connection.remoteIPKey, value: ip)
                }
                if !params.isEmpty {
                    conn = conn.mergeParams(params)
                }

                // Run the plug pipeline (auth, sessions, etc.)
                if let plug {
                    conn = try await plug(conn)
                    guard !conn.isHalted else { return .dontUpgrade }
                }

                // Run the connect handler to authorize the upgrade
                let wsConn: WSConnection
                do {
                    wsConn = try await route.connectHandler(conn)
                } catch {
                    return .dontUpgrade
                }

                let messageHandler = route.messageHandler

                // Upgrade — bridge Hummingbird WS types to Nexus types
                let handler: WebSocketDataHandler<HTTP1WebSocketUpgradeChannel.Context> = {
                    inbound, outbound, _ in

                    let send: @Sendable (WSMessage) async throws -> Void = { message in
                        switch message {
                        case .text(let text):
                            try await outbound.write(.text(text))
                        case .binary(let data):
                            try await outbound.write(.binary(ByteBuffer(bytes: data)))
                        case .pong:
                            try await outbound.write(.pong)
                        case .ping:
                            // Ping is handled automatically by the framework
                            break
                        case .close(let code, let reason):
                            let errorCode: WebSocketErrorCode = code.map {
                                WebSocketErrorCode(codeNumber: Int($0))
                            } ?? .normalClosure
                            try await outbound.close(errorCode, reason: reason)
                        }
                    }

                    let finalWsConn = WSConnection(assigns: wsConn.assigns, send: send)

                    for try await message in inbound.messages(maxSize: 1_048_576) {
                        let nexusMessage: WSMessage
                        switch message {
                        case .text(let text):
                            nexusMessage = .text(text)
                        case .binary(let buffer):
                            nexusMessage = .binary(Data(buffer.readableBytesView))
                        }
                        do {
                            try await messageHandler(finalWsConn, nexusMessage)
                        } catch {
                            // Handler errors don't crash the server.
                            // The connection remains open for subsequent messages.
                        }
                    }
                }

                return .upgrade([:], handler)
            }

            return .dontUpgrade
        }
    }
}
