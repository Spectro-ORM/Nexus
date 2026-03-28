import Testing
import Foundation
import HTTPTypes
@testable import Nexus

@Suite("WebSocket Core Types")
struct WebSocketTests {

    // MARK: - WSMessage

    @Test("WSMessage text equality")
    func test_wsMessage_textEquality() {
        #expect(WSMessage.text("hello") == WSMessage.text("hello"))
        #expect(WSMessage.text("hello") != WSMessage.text("world"))
    }

    @Test("WSMessage binary equality")
    func test_wsMessage_binaryEquality() {
        let data = Data("binary".utf8)
        #expect(WSMessage.binary(data) == WSMessage.binary(data))
        #expect(WSMessage.binary(data) != WSMessage.binary(Data("other".utf8)))
    }

    @Test("WSMessage ping/pong equality")
    func test_wsMessage_pingPongEquality() {
        #expect(WSMessage.ping == WSMessage.ping)
        #expect(WSMessage.pong == WSMessage.pong)
        #expect(WSMessage.ping != WSMessage.pong)
    }

    @Test("WSMessage close equality")
    func test_wsMessage_closeEquality() {
        #expect(WSMessage.close(code: 1000, reason: "bye") == WSMessage.close(code: 1000, reason: "bye"))
        #expect(WSMessage.close(code: 1000, reason: nil) != WSMessage.close(code: 1001, reason: nil))
        #expect(WSMessage.close(code: nil, reason: nil) == WSMessage.close(code: nil, reason: nil))
    }

    @Test("WSMessage different cases are not equal")
    func test_wsMessage_differentCases_notEqual() {
        #expect(WSMessage.text("hello") != WSMessage.binary(Data("hello".utf8)))
        #expect(WSMessage.ping != WSMessage.close(code: nil, reason: nil))
    }

    // MARK: - WSConnection

    @Test("WSConnection carries assigns")
    func test_wsConnection_carriesAssigns() {
        let ws = WSConnection(assigns: ["user": "alice"], send: { _ in })
        #expect(ws.assigns["user"] as? String == "alice")
    }

    @Test("WSConnection assign returns new copy")
    func test_wsConnection_assignReturnsCopy() {
        let ws = WSConnection(assigns: ["a": 1], send: { _ in })
        let ws2 = ws.assign(key: "b", value: 2)
        #expect(ws2.assigns["a"] as? Int == 1)
        #expect(ws2.assigns["b"] as? Int == 2)
        // Original unchanged
        #expect(ws.assigns["b"] == nil)
    }

    @Test("WSConnection send function is callable")
    func test_wsConnection_sendIsCalled() async throws {
        let sent = MessageCollector()
        let ws = WSConnection(assigns: [:]) { message in
            await sent.add(message)
        }
        try await ws.send(.text("hello"))
        try await ws.send(.binary(Data("data".utf8)))

        let messages = await sent.messages
        #expect(messages.count == 2)
        #expect(messages[0] == .text("hello"))
        #expect(messages[1] == .binary(Data("data".utf8)))
    }

    @Test("WSConnection default empty assigns")
    func test_wsConnection_defaultEmptyAssigns() {
        let ws = WSConnection(send: { _ in })
        #expect(ws.assigns.isEmpty)
    }

    // MARK: - Assign Propagation from Connection

    @Test("HTTP Connection assigns can flow to WSConnection")
    func test_assignPropagation_httpToWebSocket() async throws {
        // Simulate: HTTP pipeline sets assigns, connect handler propagates them
        let httpConn = Connection(
            request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/ws")
        ).assign(key: "request_id", value: "req-123")
            .assign(key: "user", value: "bob")

        let connectHandler: WSConnectHandler = { conn in
            WSConnection(assigns: conn.assigns, send: { _ in })
        }

        let wsConn = try await connectHandler(httpConn)
        #expect(wsConn.assigns["request_id"] as? String == "req-123")
        #expect(wsConn.assigns["user"] as? String == "bob")
    }

    // MARK: - WSHandler / WSConnectHandler Type Checks

    @Test("WSHandler can be constructed as a closure")
    func test_wsHandler_closureConstruction() async throws {
        let handler: WSHandler = { ws, message in
            if case .text(let t) = message {
                try await ws.send(.text("Echo: \(t)"))
            }
        }

        let sent = MessageCollector()
        let ws = WSConnection(assigns: [:]) { msg in await sent.add(msg) }
        try await handler(ws, .text("hi"))

        let messages = await sent.messages
        #expect(messages == [.text("Echo: hi")])
    }

    @Test("WSConnectHandler can reject upgrade by throwing")
    func test_wsConnectHandler_rejectsWithThrow() async throws {
        struct UpgradeRejected: Error {}
        let connectHandler: WSConnectHandler = { _ in
            throw UpgradeRejected()
        }

        let conn = Connection(
            request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/ws")
        )
        await #expect(throws: UpgradeRejected.self) {
            _ = try await connectHandler(conn)
        }
    }
}

// MARK: - Helpers

private actor MessageCollector {
    var messages: [WSMessage] = []
    func add(_ message: WSMessage) { messages.append(message) }
}
