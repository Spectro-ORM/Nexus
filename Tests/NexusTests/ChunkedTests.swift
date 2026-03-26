import Testing
import Foundation
import HTTPTypes
@testable import Nexus

// MARK: - Chunked Response

@Suite("Chunked Response")
struct ChunkedResponseTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/"
        )
        return Connection(request: request)
    }

    @Test("test_sendChunked_setsStreamResponseBody")
    func test_sendChunked_setsStreamResponseBody() {
        let conn = makeConnection().sendChunked { writer in
            writer.finish()
        }
        if case .stream = conn.responseBody {
            // expected
        } else {
            Issue.record("Expected .stream responseBody")
        }
    }

    @Test("test_sendChunked_haltsConnection")
    func test_sendChunked_haltsConnection() {
        let conn = makeConnection().sendChunked { writer in
            writer.finish()
        }
        #expect(conn.isHalted == true)
    }

    @Test("test_sendChunked_setsStatus")
    func test_sendChunked_setsStatus() {
        let conn = makeConnection().sendChunked(status: .created) { writer in
            writer.finish()
        }
        #expect(conn.response.status == .created)
    }

    @Test("test_sendChunked_writesChunksInOrder")
    func test_sendChunked_writesChunksInOrder() async throws {
        let conn = makeConnection().sendChunked { writer in
            writer.write("chunk1")
            writer.write("chunk2")
            writer.write("chunk3")
            writer.finish()
        }
        guard case .stream(let stream) = conn.responseBody else {
            Issue.record("Expected .stream responseBody")
            return
        }
        var chunks: [String] = []
        for try await data in stream {
            if let str = String(data: data, encoding: .utf8) {
                chunks.append(str)
            }
        }
        #expect(chunks == ["chunk1", "chunk2", "chunk3"])
    }

    @Test("test_sendChunked_finishTerminatesStream")
    func test_sendChunked_finishTerminatesStream() async throws {
        let conn = makeConnection().sendChunked { writer in
            writer.write("only")
            writer.finish()
        }
        guard case .stream(let stream) = conn.responseBody else {
            Issue.record("Expected .stream responseBody")
            return
        }
        var count = 0
        for try await _ in stream {
            count += 1
        }
        #expect(count == 1)
    }

    @Test("test_sendChunked_errorTerminatesStream")
    func test_sendChunked_errorTerminatesStream() async {
        struct TestError: Error {}
        let conn = makeConnection().sendChunked { writer in
            writer.write("before error")
            writer.finish(throwing: TestError())
        }
        guard case .stream(let stream) = conn.responseBody else {
            Issue.record("Expected .stream responseBody")
            return
        }
        var receivedError = false
        do {
            for try await _ in stream {}
        } catch {
            receivedError = true
        }
        #expect(receivedError)
    }

    @Test("test_sendChunked_writeData")
    func test_sendChunked_writeData() async throws {
        let payload = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F])  // "Hello"
        let conn = makeConnection().sendChunked { writer in
            writer.write(payload)
            writer.finish()
        }
        guard case .stream(let stream) = conn.responseBody else {
            Issue.record("Expected .stream responseBody")
            return
        }
        var received = Data()
        for try await data in stream {
            received.append(data)
        }
        #expect(received == payload)
    }
}

// MARK: - SSE Event Formatting

@Suite("SSE Event")
struct SSEEventTests {

    @Test("test_sseEvent_formatsDataOnly")
    func test_sseEvent_formatsDataOnly() {
        let result = sseEvent(data: "hello")
        #expect(result == "data: hello\n\n")
    }

    @Test("test_sseEvent_formatsAllFields")
    func test_sseEvent_formatsAllFields() {
        let result = sseEvent(data: "msg", event: "chat", id: "42", retry: 3000)
        #expect(result == "id: 42\nevent: chat\nretry: 3000\ndata: msg\n\n")
    }

    @Test("test_sseEvent_multilineData")
    func test_sseEvent_multilineData() {
        let result = sseEvent(data: "line1\nline2")
        #expect(result == "data: line1\ndata: line2\n\n")
    }

    @Test("test_sseEvent_eventType")
    func test_sseEvent_eventType() {
        let result = sseEvent(data: "msg", event: "update")
        #expect(result == "event: update\ndata: msg\n\n")
    }

    @Test("test_sseEvent_idOnly")
    func test_sseEvent_idOnly() {
        let result = sseEvent(data: "payload", id: "99")
        #expect(result == "id: 99\ndata: payload\n\n")
    }

    @Test("test_sseEvent_retryOnly")
    func test_sseEvent_retryOnly() {
        let result = sseEvent(data: "reconnect", retry: 5000)
        #expect(result == "retry: 5000\ndata: reconnect\n\n")
    }
}
