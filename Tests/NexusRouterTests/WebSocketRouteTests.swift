import Foundation
import Testing
import HTTPTypes
@testable import Nexus
@testable import NexusRouter

@Suite("WebSocket Routes")
struct WebSocketRouteTests {

    @Test("WS() creates a WSRoute with correct path")
    func test_ws_createsRouteWithPath() {
        let route = WS("/ws/echo", onUpgrade: { conn in
            WSConnection(assigns: conn.assigns, send: { _ in })
        }, onMessage: { _, _ in })

        #expect(route.path == "/ws/echo")
    }

    @Test("WSRoute matches exact path")
    func test_wsRoute_matchesExactPath() {
        let route = WS("/ws/chat", onUpgrade: { conn in
            WSConnection(send: { _ in })
        }, onMessage: { _, _ in })

        #expect(route.match("/ws/chat") != nil)
        #expect(route.match("/ws/other") == nil)
        #expect(route.match("/") == nil)
    }

    @Test("WSRoute matches path with parameters")
    func test_wsRoute_matchesPathWithParams() {
        let route = WS("/ws/:room", onUpgrade: { conn in
            WSConnection(send: { _ in })
        }, onMessage: { _, _ in })

        let params = route.match("/ws/general")
        #expect(params?["room"] == "general")
        #expect(route.match("/ws") == nil)
    }

    @Test("WSRoute connectHandler receives Connection")
    func test_wsRoute_connectHandlerReceivesConnection() async throws {
        let route = WS("/ws/echo", onUpgrade: { conn in
            let path = conn.request.path ?? "unknown"
            return WSConnection(assigns: ["path": path], send: { _ in })
        }, onMessage: { _, _ in })

        let conn = Connection(
            request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/ws/echo")
        )
        let wsConn = try await route.connectHandler(conn)
        #expect(wsConn.assigns["path"] as? String == "/ws/echo")
    }

    @Test("WSRoute messageHandler processes messages")
    func test_wsRoute_messageHandlerProcesses() async throws {
        let received = ReceivedMessages()
        let route = WS("/ws/echo", onUpgrade: { conn in
            WSConnection(send: { _ in })
        }, onMessage: { _, message in
            await received.add(message)
        })

        let wsConn = WSConnection(send: { _ in })
        try await route.messageHandler(wsConn, .text("hello"))
        try await route.messageHandler(wsConn, .binary(Data("data".utf8)))

        let messages = await received.messages
        #expect(messages.count == 2)
        #expect(messages[0] == .text("hello"))
    }
}

private actor ReceivedMessages {
    var messages: [WSMessage] = []
    func add(_ msg: WSMessage) { messages.append(msg) }
}
