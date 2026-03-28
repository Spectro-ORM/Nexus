import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Assign Plug")
struct AssignPlugTests {

    @Test("Static value is stored in assigns")
    func test_assign_staticValue_storesInAssigns() async throws {
        let conn = makeConn()
        let plug = assign("db_name", value: "production")
        let result = try await plug(conn)
        #expect(result.assigns["db_name"] as? String == "production")
    }

    @Test("Closure value is evaluated per request")
    func test_assign_closureValue_evaluatedPerRequest() async throws {
        let counter = Counter()
        let plug = assign("count") { counter.increment() }

        let conn1 = try await plug(makeConn())
        let conn2 = try await plug(makeConn())

        #expect(conn1.assigns["count"] as? Int == 1)
        #expect(conn2.assigns["count"] as? Int == 2)
    }

    @Test("Value persists through subsequent plugs")
    func test_assign_valuePersists_throughPipeline() async throws {
        let injector = assign("service", value: "injected")
        let reader: Plug = { conn in
            let val = conn.assigns["service"] as? String ?? "missing"
            return conn.assign(key: "read_value", value: val)
        }
        let app = pipeline([injector, reader])
        let result = try await app(makeConn())
        #expect(result.assigns["read_value"] as? String == "injected")
    }

    @Test("Plug does not halt the connection")
    func test_assign_doesNotHalt() async throws {
        let plug = assign("key", value: 42)
        let result = try await plug(makeConn())
        #expect(!result.isHalted)
    }

    @Test("Works with different Sendable types")
    func test_assign_differentTypes() async throws {
        struct Config: Sendable { let name: String }

        let conn = makeConn()
        let p = pipeline([
            assign("string_val", value: "hello"),
            assign("int_val", value: 42),
            assign("config", value: Config(name: "test")),
        ])
        let result = try await p(conn)

        #expect(result.assigns["string_val"] as? String == "hello")
        #expect(result.assigns["int_val"] as? Int == 42)
        let config = result.assigns["config"] as? Config
        #expect(config?.name == "test")
    }

    @Test("Works with actor references")
    func test_assign_actorReference() async throws {
        let store = DataStore()
        let plug = assign("store", value: store)
        let result = try await plug(makeConn())
        let retrieved = result.assigns["store"] as? DataStore
        #expect(retrieved != nil)
    }
}

// MARK: - Helpers

private func makeConn() -> Connection {
    Connection(request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"))
}

private final class Counter: Sendable {
    private let _value = LockedValue(0)

    func increment() -> Int {
        _value.withLock { val in
            val += 1
            return val
        }
    }
}

/// Thread-safe locked value for test helpers.
private final class LockedValue<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) { self.value = value }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

private actor DataStore {
    var items: [String] = []
    func add(_ item: String) { items.append(item) }
}
