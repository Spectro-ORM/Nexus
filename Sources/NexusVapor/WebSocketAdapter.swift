import Foundation
import Vapor
import NIOCore
import NIOWebSocket
import HTTPTypes
import Nexus
import NexusRouter

// MARK: - Vapor to HTTPTypes Conversion

extension Vapor.HTTPMethod {
    /// Converts Vapor HTTPMethod to HTTPTypes HTTPRequest.Method
    var toHTTPRequestMethod: HTTPRequest.Method {
        switch self {
        case .GET: return .get
        case .POST: return .post
        case .PUT: return .put
        case .DELETE: return .delete
        case .PATCH: return .patch
        case .HEAD: return .head
        case .OPTIONS: return .options
        case .TRACE: return .trace
        default: return .get // Fallback for custom methods
        }
    }
}

extension Application {

    /// Registers Nexus WebSocket routes with the Vapor application.
    ///
    /// This method integrates Nexus's WebSocket abstraction with Vapor's
    /// WebSocket infrastructure, allowing you to use the same ``WSRoute``
    /// definitions across both Hummingbird and Vapor.
    ///
    /// ## Overview
    ///
    /// The method registers a catch-all route at `/ws/**` that intercepts
    /// potential WebSocket upgrade requests. For each incoming request:
    ///
    /// 1. **Route Matching**: Attempts to match the request path against
    ///    registered ``WSRoute`` definitions.
    ///
    /// 2. **Request Translation**: Converts the Vapor request to a Nexus
    ///    ``Connection``, including remote IP and route parameters.
    ///
    /// 3. **Pipeline Execution**: Optionally runs a plug pipeline for
    ///    authentication, session management, etc.
    ///
    /// 4. **Upgrade Authorization**: Calls the route's ``WSConnectHandler``
    ///    to authorize the WebSocket upgrade.
    ///
    /// 5. **Connection Upgrade**: Upgrades to WebSocket and bridges Vapor's
    ///    WebSocket API to Nexus's ``WSConnection`` abstraction.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// import Vapor
    /// import NexusVapor
    ///
    /// // Define WebSocket routes
    /// let wsRoutes = [
    ///     WS("/ws/echo", onUpgrade: { conn in
    ///         // Authorize the upgrade
    ///         let userId = conn.assigns["user_id"] as? String
    ///         guard userId != nil else {
    ///             throw Abort(.unauthorized)
    ///         }
    ///         return WSConnection(assigns: conn.assigns, send: { _ in })
    ///     }, onMessage: { ws, msg in
    ///         // Handle incoming messages
    ///         if case .text(let text) = msg {
    ///             try await ws.send(.text("Echo: \(text)"))
    ///         }
    ///     }),
    /// ]
    ///
    /// // Register with Vapor
    /// let app = Application(.default)
    /// app.nexusWebSocket(routes: wsRoutes, plug: authPipeline)
    ///
    /// try await app.execute()
    /// ```
    ///
    /// ## Route Matching
    ///
    /// Routes are matched in the order they appear in the `routes` array.
    /// The first matching route handles the request. If no route matches,
    /// the method returns a 404 response.
    ///
    /// ## Plug Pipeline
    ///
    /// The optional `plug` parameter allows you to run a Nexus plug pipeline
    /// before the WebSocket upgrade. This is useful for:
    ///
    /// - **Authentication**: Verify the user's identity before upgrading
    /// - **Session Management**: Load session data into connection assigns
    /// - **Request ID**: Generate and track request IDs
    /// - **Logging**: Log the upgrade attempt
    ///
    /// If the plug pipeline halts the connection or throws an error, the
    /// upgrade is aborted with an appropriate HTTP response (403 or 500).
    ///
    /// ## Error Handling
    ///
    /// - **Route not found**: Returns 404 Not Found
    /// - **Halted connection**: Returns 403 Forbidden
    /// - **Pipeline error**: Returns 500 Internal Server Error
    /// - **Upgrade authorization failure**: Returns 403 Forbidden
    /// - **Message handler errors**: Logged but don't close the connection
    ///
    /// ## WebSocket Message Types
    ///
    /// All ``WSMessage`` types are supported:
    ///
    /// - ``WSMessage/text(_:)`` - Text messages
    /// - ``WSMessage/binary(_:)`` - Binary data
    /// - ``WSMessage/ping`` - Ping frames (handled automatically by Vapor)
    /// - ``WSMessage/pong`` - Pong frames
    /// - ``WSMessage/close(_:reason:)`` - Close frames with optional code and reason
    ///
    /// ## Vapor-Specific Behavior
    ///
    /// - Vapor automatically handles ping/pong frames for connection health
    /// - Message handlers are invoked in a `Task` to support async operations
    /// - Handler errors don't crash the server or close the connection
    /// - The connection remains open after handler errors for subsequent messages
    ///
    /// ## Related Types
    ///
    /// - ``WSRoute`` - WebSocket route definition
    /// - ``WSConnection`` - Nexus WebSocket connection abstraction
    /// - ``WSMessage`` - WebSocket message types
    /// - ``WSConnectHandler`` - Authorization handler for upgrades
    /// - ``WSMessageHandler`` - Message handler callback
    /// - ``Plug`` - Plug pipeline type for pre-upgrade processing
    ///
    /// - Parameters:
    ///   - routes: An array of ``WSRoute`` definitions to register with
    ///     the Vapor application. Routes are matched in order.
    ///   - plug: An optional plug pipeline to run on the upgrade request
    ///     before invoking the route's ``WSConnectHandler``. Use this to
    ///     let authentication, session, and request-ID plugs populate
    ///     ``Connection/assigns`` before the upgrade. Defaults to `nil`.
    ///
    /// ## Note
    ///
    /// Vapor's WebSocket implementation automatically handles ping/pong frames
    /// and connection lifecycle. You don't need to implement these yourself.
    ///
    /// ## See Also
    ///
    /// - ``WSRoute`` - Defining WebSocket routes
    /// - ``WSConnection`` - Using WebSocket connections
    /// - <doc:WebSocket> - WebSocket guide
    public func nexusWebSocket(
        routes: [WSRoute],
        plug: Plug? = nil
    ) {
        // @MX:ANCHOR:WebSocket route registration
        // @MX:REASON:Primary integration point for Nexus WebSocket routes with Vapor
        // @MX:SPEC:030

        // Register a catch-all route that intercepts potential WebSocket upgrades
        // before other middleware can handle them.
        self.get("ws", "**") { req in
            // Extract the full path from the request
            let path = req.url.path

            // Try to match against registered routes
            for route in routes {
                guard let params = route.match(path) else { continue }

                // Build a Nexus Connection from the Vapor request
                // Build HTTPRequest from Vapor request
                var httpRequest = HTTPRequest(
                    method: req.method.toHTTPRequestMethod,
                    scheme: "http",
                    authority: req.headers.first(name: .host) ?? "localhost",
                    path: req.url.path
                )
                httpRequest.headerFields = req.headers.reduce(into: HTTPFields()) { fields, header in
                    fields[HTTPField.Name(header.name)!] = header.value
                }

                var conn = Connection(request: httpRequest)

                // Populate remote IP if available
                if let ip = req.remoteAddress?.ipAddress {
                    conn = conn.assign(key: Connection.remoteIPKey, value: ip)
                }

                // Merge route parameters into assigns
                if !params.isEmpty {
                    conn = conn.mergeParams(params)
                }

                // Run the plug pipeline (auth, sessions, etc.)
                let finalConn: Connection
                do {
                    if let plug {
                        let processedConn = try await plug(conn)
                        // Check if connection was halted during plug execution
                        guard !processedConn.isHalted else {
                            return Response(status: .forbidden)
                        }
                        finalConn = processedConn
                    } else {
                        finalConn = conn
                    }
                } catch {
                    // Infrastructure errors during plug execution return 500
                    return Response(status: .internalServerError)
                }

                // Run the connect handler to authorize the upgrade
                let wsConn: WSConnection
                do {
                    wsConn = try await route.connectHandler(finalConn)
                } catch {
                    // Authorization failure - don't upgrade
                    return Response(status: .forbidden)
                }

                // Extract the route parameter captured by Vapor's "**"
                // Vapor's "**" captures the path after "/ws/"
                _ = req.parameters.get("**") ?? ""

                // Upgrade the connection to WebSocket
                return req.webSocket { req, ws in
                    // Bridge Vapor WS types to Nexus types

                    let send: @Sendable (WSMessage) async throws -> Void = { message in
                        switch message {
                        case .text(let text):
                            try await ws.send(text)
                        case .binary(let data):
                            try await ws.send(raw: data, opcode: .binary)
                        case .pong:
                            try await ws.send(raw: Data(), opcode: .pong)
                        case .ping:
                            // Ping is handled automatically by Vapor
                            break
                        case .close(let code, _):
                            if let code = code {
                                try await ws.close(code: WebSocketErrorCode(codeNumber: Int(code)))
                            } else {
                                try await ws.close()
                            }
                        }
                    }

                    let finalWsConn = WSConnection(assigns: wsConn.assigns, send: send)
                    let messageHandler = route.messageHandler

                    // Listen for incoming messages
                    ws.onText { ws, text in
                        let nexusMessage = WSMessage.text(text)
                        Task {
                            do {
                                try await messageHandler(finalWsConn, nexusMessage)
                            } catch {
                                // Handler errors don't crash the server.
                                // The connection remains open for subsequent messages.
                            }
                        }
                    }

                    ws.onBinary { ws, data in
                        let nexusMessage = WSMessage.binary(Data(buffer: data))
                        Task {
                            do {
                                try await messageHandler(finalWsConn, nexusMessage)
                            } catch {
                                // Handler errors don't crash the server.
                            }
                        }
                    }

                    // Handle close events
                    ws.onClose.whenComplete { result in
                        // Connection closed
                    }
                }
            }

            // No route matched - return 404
            return Response(status: .notFound)
        }
    }
}

// @MX:NOTE:Vapor's WebSocket API uses callback-based handlers (onText, onBinary)
// @MX:NOTE:We wrap callbacks in Task to handle async message handlers
// @MX:NOTE:Ping/pong is handled automatically by Vapor's WebSocket implementation
