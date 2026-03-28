# Spec: WebSocket Support

**Status:** Proposed
**Date:** 2026-03-28
**Depends on:** Nexus core (complete), NexusHummingbird adapter (complete)

---

## 1. Goal

Add WebSocket support to Nexus, enabling real-time bidirectional communication.
This is the biggest missing piece compared to Phoenix (Channels/LiveView) and
opens up use cases like live dashboards, chat, notifications, and streaming
updates. The design should follow Nexus's functional philosophy: WebSocket
handlers are functions that transform messages, not protocol conformances.

---

## 2. Design Principles

- **Functions, not protocols.** WebSocket handlers are closures, consistent
  with the Plug philosophy.
- **Layered.** Core WebSocket types live in `Nexus`. The actual upgrade
  mechanism lives in `NexusHummingbird` (since it depends on Hummingbird's
  WebSocket APIs).
- **No channel abstraction yet.** Start with raw WebSocket support. Topics,
  rooms, and PubSub can be layered on later.

---

## 3. Scope

### 3.1 Core Types (Nexus target)

```swift
// Sources/Nexus/WebSocket/WSMessage.swift
public enum WSMessage: Sendable {
    case text(String)
    case binary(Data)
    case ping
    case pong
    case close(code: UInt16?, reason: String?)
}

// Sources/Nexus/WebSocket/WSConnection.swift
public struct WSConnection: Sendable {
    public let assigns: [String: any Sendable]
    public let send: @Sendable (WSMessage) async throws -> Void

    public func assign(key: String, value: some Sendable) -> WSConnection {
        var copy = self
        // ... same pattern as Connection
        return copy
    }
}

// Sources/Nexus/WebSocket/WSHandler.swift
public typealias WSHandler = @Sendable (WSConnection, WSMessage) async throws -> Void
public typealias WSConnectHandler = @Sendable (Connection) async throws -> WSConnection
```

### 3.2 Router Integration

Add a `WS` route builder function:

```swift
// Sources/NexusRouter/WebSocketRoute.swift
WS("/ws/notifications") { conn -> WSConnection in
    // Upgrade decision — can inspect conn, reject with throw
    let userId = conn.params["user_id"]!
    return WSConnection(assigns: ["user_id": userId], send: { _ in })
} onMessage: { ws, message in
    switch message {
    case .text(let text):
        try await ws.send(.text("Echo: \(text)"))
    case .close:
        break
    default:
        break
    }
}
```

### 3.3 Hummingbird WebSocket Adapter

```swift
// Sources/NexusHummingbird/WebSocketAdapter.swift
```

Bridge Nexus's `WSHandler` to Hummingbird's `WebSocketUpgradeMiddleware`. This
adapter:
- Intercepts WebSocket upgrade requests matching registered routes
- Runs the `WSConnectHandler` to produce a `WSConnection`
- Delegates message handling to the `WSHandler` closure
- Maps between Hummingbird's `WebSocket.Frame` and Nexus's `WSMessage`

### 3.4 Connection Carries Assigns to WebSocket

The HTTP `Connection` that initiated the upgrade passes its `assigns` to the
`WSConnection`. This means authentication plugs, session data, and request IDs
flow naturally into the WebSocket context:

```swift
let pipeline = pipeline([
    requestId(),
    sessionPlug(secret: "..."),
    routerPlug,  // router handles WS upgrade
])
```

The `WSConnectHandler` receives the fully-processed `Connection` with all
assigns populated by upstream plugs.

---

## 4. Acceptance Criteria

- [ ] `WSMessage` enum exists with `.text`, `.binary`, `.ping`, `.pong`, `.close` cases
- [ ] `WSConnection` struct exists with `assigns` and `send` function
- [ ] `WSHandler` typealias is defined as `@Sendable (WSConnection, WSMessage) async throws -> Void`
- [ ] `WSConnectHandler` typealias allows inspecting the HTTP `Connection` before upgrade
- [ ] `WS()` route builder function registers WebSocket routes
- [ ] Hummingbird adapter bridges WebSocket upgrades to Nexus handlers
- [ ] Assigns from HTTP pipeline plugs are available in `WSConnection.assigns`
- [ ] Text messages can be sent and received
- [ ] Binary messages can be sent and received
- [ ] Close frames are handled gracefully
- [ ] WebSocket handler errors don't crash the server
- [ ] Multiple concurrent WebSocket connections work independently
- [ ] All types are `Sendable` and compile under Swift 6 strict concurrency
- [ ] Tests cover: upgrade handshake, text echo, binary echo, close handling, assign propagation
- [ ] Integration test with Hummingbird: connect via WebSocket client, exchange messages

---

## 5. Verification

1. Start DonutShop with a `/ws/echo` endpoint
2. Connect with `websocat ws://127.0.0.1:8080/ws/echo`
3. Send a text message, receive echo
4. Disconnect cleanly

---

## 6. Non-goals

- No channel/topic abstraction (Phoenix Channels equivalent). That's a
  follow-up spec.
- No PubSub system. WebSocket handlers manage their own state for now.
- No LiveView equivalent. Far future.
- No automatic reconnection or heartbeat protocol (client responsibility).
- No WebSocket compression (`permessage-deflate`). Can be added later.

---

## 7. Future Work

After raw WebSocket support is stable:
- **Channels:** Topic-based routing within a WebSocket connection
- **PubSub:** Server-side broadcast to subscribers
- **Presence:** Track connected users across nodes
- **LiveView-inspired:** Server-rendered UI with WebSocket diff updates
