import Testing
import Foundation
import HTTPTypes
@testable import Nexus

@Suite("Connection")
struct ConnectionTests {

    // MARK: - Initialisation

    @Test("test_connection_init_setsDefaultResponseStatus")
    func test_connection_init_setsDefaultResponseStatus() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request)
        #expect(conn.response.status == .ok)
    }

    @Test("test_connection_init_isNotHalted")
    func test_connection_init_isNotHalted() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request)
        #expect(conn.isHalted == false)
    }

    @Test("test_connection_init_assignsIsEmpty")
    func test_connection_init_assignsIsEmpty() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request)
        #expect(conn.assigns.isEmpty)
    }

    @Test("test_connection_init_requestBodyDefaultsToEmpty")
    func test_connection_init_requestBodyDefaultsToEmpty() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request)
        if case .empty = conn.requestBody { } else { Issue.record("Expected .empty requestBody") }
    }

    // MARK: - Halting

    @Test("test_connection_halted_returnsHaltedCopy")
    func test_connection_halted_returnsHaltedCopy() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request).halted()
        #expect(conn.isHalted == true)
    }

    @Test("test_connection_halted_doesNotMutateOriginal")
    func test_connection_halted_doesNotMutateOriginal() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let original = Connection(request: request)
        let _ = original.halted()
        #expect(original.isHalted == false)
    }

    // MARK: - Assigns

    @Test("test_connection_assign_storesValue")
    func test_connection_assign_storesValue() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request)
            .assign(key: "userID", value: "abc-123")
        #expect(conn.assigns["userID"] as? String == "abc-123")
    }

    @Test("test_connection_assign_doesNotMutateOriginal")
    func test_connection_assign_doesNotMutateOriginal() {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        let original = Connection(request: request)
        let _ = original.assign(key: "foo", value: "bar")
        #expect(original.assigns.isEmpty)
    }
}

// MARK: - Plug Composition Tests

@Suite("Plug Composition")
struct PlugCompositionTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request)
    }

    @Test("test_pipe_runsFirstThenSecond")
    func test_pipe_runsFirstThenSecond() async throws {
        var order: [Int] = []
        let first: Plug = { conn in order.append(1); return conn }
        let second: Plug = { conn in order.append(2); return conn }
        let composed = pipe(first, second)
        _ = try await composed(makeConnection())
        #expect(order == [1, 2])
    }

    @Test("test_pipe_shortCircuitsWhenFirstHalts")
    func test_pipe_shortCircuitsWhenFirstHalts() async throws {
        var secondCalled = false
        let first: Plug = { conn in conn.halted() }
        let second: Plug = { conn in secondCalled = true; return conn }
        let composed = pipe(first, second)
        _ = try await composed(makeConnection())
        #expect(secondCalled == false)
    }

    @Test("test_pipeline_appliesAllPlugs")
    func test_pipeline_appliesAllPlugs() async throws {
        let counter = Counter()
        let plugs: [Plug] = (1...5).map { _ in
            { conn in
                await counter.increment()
                return conn
            }
        }
        let p = pipeline(plugs)
        _ = try await p(makeConnection())
        let count = await counter.value
        #expect(count == 5)
    }
}

// MARK: - Helpers

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
