import Testing
import HTTPTypes
@testable import Nexus
import NexusTest

// @unchecked Sendable: only used in single-threaded test context
private final class LockedFlag: @unchecked Sendable {
    private(set) var value = false
    func set() { value = true }
}

@Suite("ModulePlug")
struct ModulePlugTests {

    // MARK: - Simple module plug

    struct EchoPlug: ModulePlug {
        let label: String

        func call(_ connection: Connection) async throws -> Connection {
            connection.assign(key: "echo_label", value: label)
        }
    }

    @Test("module plug sets assigns")
    func test_modulePlug_call_setsAssign() async throws {
        let plug = EchoPlug(label: "test")
        let conn = TestConnection.build(path: "/")
        let result = try await plug.call(conn)
        #expect(result.assigns["echo_label"] as? String == "test")
    }

    @Test("asPlug converts to Plug function type")
    func test_modulePlug_asPlug_returnsPlug() async throws {
        let plug = EchoPlug(label: "via-asPlug")
        let asPlug: Plug = plug.asPlug()
        let conn = TestConnection.build(path: "/")
        let result = try await asPlug(conn)
        #expect(result.assigns["echo_label"] as? String == "via-asPlug")
    }

    @Test("module plug works inside pipeline")
    func test_modulePlug_insidePipeline_executesInOrder() async throws {
        struct FirstPlug: ModulePlug {
            func call(_ connection: Connection) async throws -> Connection {
                connection.assign(key: "order", value: "first")
            }
        }
        struct SecondPlug: ModulePlug {
            func call(_ connection: Connection) async throws -> Connection {
                let prev = connection.assigns["order"] as? String ?? ""
                return connection.assign(key: "order", value: prev + "-second")
            }
        }
        let app = pipeline([FirstPlug().asPlug(), SecondPlug().asPlug()])
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["order"] as? String == "first-second")
    }

    // MARK: - Halting

    struct HaltingPlug: ModulePlug {
        func call(_ connection: Connection) async throws -> Connection {
            connection.respond(status: .unauthorized, body: .string("no"))
        }
    }

    @Test("halted module plug stops pipeline")
    func test_modulePlug_halted_stopsPipeline() async throws {
        let called = LockedFlag()
        let second: Plug = { conn in
            called.set()
            return conn
        }
        let app = pipeline([HaltingPlug().asPlug(), second])
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .unauthorized)
        #expect(!called.value)
    }

    // MARK: - Throwing

    struct ThrowingPlug: ModulePlug {
        struct InfraError: Error {}

        func call(_ connection: Connection) async throws -> Connection {
            throw InfraError()
        }
    }

    @Test("throwing module plug propagates error")
    func test_modulePlug_throws_propagatesError() async throws {
        let plug = ThrowingPlug()
        let conn = TestConnection.build(path: "/")
        await #expect(throws: ThrowingPlug.InfraError.self) {
            _ = try await plug.call(conn)
        }
    }

    // MARK: - with rescueErrors

    @Test("module plug works with rescueErrors")
    func test_modulePlug_withRescueErrors_catchesNexusHTTPError() async throws {
        struct ErrorPlug: ModulePlug {
            func call(_ connection: Connection) async throws -> Connection {
                throw NexusHTTPError(.forbidden, message: "Forbidden")
            }
        }
        let app = rescueErrors(ErrorPlug().asPlug())
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .forbidden)
        #expect(result.isHalted)
    }
}
