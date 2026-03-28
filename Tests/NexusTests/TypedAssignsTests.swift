import Testing
import HTTPTypes
@testable import Nexus

// MARK: - Custom Key for Testing

private enum CustomKey: AssignKey {
    typealias Value = String
}

private enum DefaultKey: AssignKey {
    typealias Value = Int
    static var defaultValue: Int? { 0 }
}

private struct ServiceConfig: Sendable {
    let name: String
    let timeout: Int
}

private enum ServiceKey: AssignKey {
    typealias Value = ServiceConfig
}

@Suite("Typed Assigns")
struct TypedAssignsTests {

    // MARK: - Typed Write + Typed Read

    @Test("Typed write and typed read round-trip")
    func test_typedAssign_writeRead_roundTrip() async throws {
        let conn = makeConn()
            .assign(CustomKey.self, value: "hello")
        #expect(conn[CustomKey.self] == "hello")
    }

    @Test("Typed write with custom struct value")
    func test_typedAssign_structValue() async throws {
        let config = ServiceConfig(name: "db", timeout: 30)
        let conn = makeConn()
            .assign(ServiceKey.self, value: config)
        let read = conn[ServiceKey.self]
        #expect(read?.name == "db")
        #expect(read?.timeout == 30)
    }

    // MARK: - Typed Write + String Read

    @Test("Typed write is readable via string key")
    func test_typedAssign_readableViaString() async throws {
        let conn = makeConn()
            .assign(CustomKey.self, value: "typed")
        let stringKey = String(describing: CustomKey.self)
        #expect(conn.assigns[stringKey] as? String == "typed")
    }

    // MARK: - String Write + Typed Read

    @Test("String write is readable via typed key")
    func test_stringAssign_readableViaTypedKey() async throws {
        let stringKey = String(describing: CustomKey.self)
        let conn = makeConn()
            .assign(key: stringKey, value: "from-string")
        #expect(conn[CustomKey.self] == "from-string")
    }

    // MARK: - Default Values

    @Test("Default value returned when key not set")
    func test_defaultValue_returnedWhenMissing() async throws {
        let conn = makeConn()
        #expect(conn[DefaultKey.self] == 0)
    }

    @Test("Explicit value overrides default")
    func test_explicitValue_overridesDefault() async throws {
        let conn = makeConn()
            .assign(DefaultKey.self, value: 42)
        #expect(conn[DefaultKey.self] == 42)
    }

    // MARK: - Nil for Unset Keys

    @Test("Returns nil for unset key without default")
    func test_unsetKey_returnsNil() async throws {
        let conn = makeConn()
        #expect(conn[CustomKey.self] == nil)
    }

    // MARK: - Built-in Keys

    @Test("RequestIdKey works with requestId() plug")
    func test_requestIdKey_worksWithPlug() async throws {
        let plug = requestId(generator: { "test-id-123" })
        let conn = try await plug(makeConn())
        #expect(conn[RequestIdKey.self] == "test-id-123")
        // Backward compat: also readable via string key
        #expect(conn.assigns["request_id"] as? String == "test-id-123")
    }

    @Test("conn.requestId convenience accessor")
    func test_requestId_convenienceAccessor() async throws {
        let plug = requestId(generator: { "abc" })
        let conn = try await plug(makeConn())
        #expect(conn.requestId == "abc")
    }

    @Test("conn.session convenience accessor")
    func test_session_convenienceAccessor() async throws {
        let conn = makeConn()
            .assign(key: Connection.sessionKey, value: ["user": "alice"])
        #expect(conn.session?["user"] == "alice")
    }

    @Test("conn.remoteIP reads from typed and string keys")
    func test_remoteIP_readsFromBothKeys() async throws {
        // Via string key (existing pattern)
        let conn1 = makeConn()
            .assign(key: Connection.remoteIPKey, value: "10.0.0.1")
        #expect(conn1.remoteIP == "10.0.0.1")

        // Via typed key
        let conn2 = makeConn()
            .assign(RemoteIPKey.self, value: "10.0.0.2")
        #expect(conn2.remoteIP == "10.0.0.2")
    }

    // MARK: - Consumer-Defined Keys

    @Test("Consumer-defined key works end-to-end")
    func test_consumerKey_endToEnd() async throws {
        // Simulate the pattern from the spec verification section
        let plug: Plug = { conn in
            conn.assign(ServiceKey.self, value: ServiceConfig(name: "prod-db", timeout: 60))
        }
        let handler: Plug = { conn in
            let config = conn[ServiceKey.self]
            return conn.assign(key: "result", value: config?.name ?? "missing")
        }

        let app = pipeline([plug, handler])
        let result = try await app(makeConn())
        #expect(result.assigns["result"] as? String == "prod-db")
    }

    // MARK: - Sendable Constraint

    @Test("AssignKey Value is constrained to Sendable")
    func test_assignKey_sendableConstraint() async throws {
        // This test verifies the Sendable constraint at compile time.
        // If it compiles, the constraint is enforced.
        let conn = makeConn()
            .assign(CustomKey.self, value: "sendable-string")
        #expect(conn[CustomKey.self] == "sendable-string")
    }
}

// MARK: - Helpers

private func makeConn() -> Connection {
    Connection(request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"))
}
