import Foundation
import Testing
import HTTPTypes
@testable import Nexus
import NexusRouter
import NexusTest

// MARK: - Test Helpers

/// Records calls for test verification
actor Recorder {
    private(set) var calls: [String] = []
    private(set) var connections: [Connection] = []

    func record(_ id: String, connection: Connection) {
        calls.append(id)
        connections.append(connection)
    }

    func record(_ id: String) {
        calls.append(id)
    }
}

/// A plug that records its execution
struct RecordingPlug: ModulePlug {
    let id: String
    let recorder: Recorder

    func call(_ connection: Connection) async throws -> Connection {
        await recorder.record(id, connection: connection)
        return connection
    }
}

/// A plug that appends to an assign value
struct AppendingPlug: ModulePlug {
    let label: String
    let key: String = "trace"

    func call(_ connection: Connection) async throws -> Connection {
        let prev = connection.assigns[key] as? String ?? ""
        return connection.assign(key: key, value: prev + label)
    }
}

/// A plug that halts with unauthorized
struct HaltingPlug: ModulePlug {
    func call(_ connection: Connection) async throws -> Connection {
        connection.respond(status: .unauthorized, body: .string("halted"))
    }
}

/// A plug that sets a flag (for checking if executed after halt)
final class ExecutionFlag: @unchecked Sendable {
    private(set) var wasExecuted = false
    func set() { wasExecuted = true }
}

// MARK: - Tests

@Suite("NamedPipeline")
struct NamedPipelineTests {

    // MARK: - Basic pipeline application

    @Test("basic pipeline executes plugs in order")
    func test_basicPipeline_executesPlugsInOrder() async throws {
        let pipeline = NamedPipeline {
            AppendingPlug(label: "A")
            AppendingPlug(label: "B")
            AppendingPlug(label: "C")
        }

        let conn = TestConnection.build(path: "/")
        let result = try await pipeline.call(conn)

        #expect(result.assigns["trace"] as? String == "ABC")
    }

    @Test("pipeline via scope applies middleware to routes")
    func test_pipelineViaScope_appliesMiddleware() async throws {
        let apiPipeline = NamedPipeline {
            AppendingPlug(label: "auth-")
        }

        let router = Router {
            scope("/api", through: apiPipeline) {
                GET("/users") { conn in
                    let trace = conn.assigns["trace"] as? String ?? ""
                    return conn.respond(status: .ok, body: .string("trace:\(trace)"))
                }
            }
        }

        let conn = TestConnection.build(path: "/api/users")
        let result = try await router(conn)

        #expect(result.response.status == .ok)
        let body = bodyString(result)
        #expect(body == "trace:auth-")
    }

    // MARK: - Reuse across scopes

    @Test("pipeline can be reused across multiple scopes")
    func test_pipelineReuse_acrossMultipleScopes() async throws {
        let apiPipeline = NamedPipeline {
            AppendingPlug(label: "common-")
        }

        let router = Router {
            scope("/api/v1", through: apiPipeline) {
                GET("/users") { conn in
                    let trace = conn.assigns["trace"] as? String ?? ""
                    return conn.respond(status: .ok, body: .string("v1:\(trace)"))
                }
            }

            scope("/api/v2", through: apiPipeline) {
                GET("/users") { conn in
                    let trace = conn.assigns["trace"] as? String ?? ""
                    return conn.respond(status: .ok, body: .string("v2:\(trace)"))
                }
            }
        }

        let conn1 = TestConnection.build(path: "/api/v1/users")
        let result1 = try await router(conn1)
        #expect(bodyString(result1) == "v1:common-")

        // Reset connection for second request
        let conn2 = TestConnection.build(path: "/api/v2/users")
        let result2 = try await router(conn2)
        #expect(bodyString(result2) == "v2:common-")
    }

    // MARK: - Integration with buildPipeline

    @Test("named pipeline works inside buildPipeline")
    func test_namedPipeline_insideBuildPipeline() async throws {
        let recorder = Recorder()

        let loggingPipeline = NamedPipeline {
            RecordingPlug(id: "log1", recorder: recorder)
            RecordingPlug(id: "log2", recorder: recorder)
        }

        let app = buildPipeline {
            RecordingPlug(id: "before", recorder: recorder)
            loggingPipeline
            RecordingPlug(id: "after", recorder: recorder)
        }

        let conn = TestConnection.build(path: "/")
        _ = try await app(conn)

        let calls = await recorder.calls
        #expect(calls == ["before", "log1", "log2", "after"])
    }

    @Test("named pipeline as module plug calls through pipeline")
    func test_namedPipelineAsModulePlug() async throws {
        let pipeline = NamedPipeline {
            AppendingPlug(label: "X")
            AppendingPlug(label: "Y")
        }

        // Use as ModulePlug (which has default asPlug())
        let asPlug: Plug = pipeline.asPlug()

        let conn = TestConnection.build(path: "/")
        let result = try await asPlug(conn)

        #expect(result.assigns["trace"] as? String == "XY")
    }

    // MARK: - Composition with inline plugs

    @Test("composition mixes named pipeline with inline plugs")
    func test_composition_withInlinePlugs() async throws {
        let recorder = Recorder()

        let authPipeline = NamedPipeline {
            RecordingPlug(id: "auth", recorder: recorder)
        }

        let app = buildPipeline {
            RecordingPlug(id: "first", recorder: recorder)
            authPipeline
            RecordingPlug(id: "last", recorder: recorder)
        }

        let conn = TestConnection.build(path: "/")
        _ = try await app(conn)

        let calls = await recorder.calls
        #expect(calls == ["first", "auth", "last"])
    }

    // MARK: - Halt handling

    @Test("halted pipeline stops execution")
    func test_haltedPipeline_stopsExecution() async throws {
        let recorder = Recorder()

        let pipeline = NamedPipeline {
            RecordingPlug(id: "before-halt", recorder: recorder)
            HaltingPlug()
            RecordingPlug(id: "after-halt", recorder: recorder)
        }

        let conn = TestConnection.build(path: "/")
        let result = try await pipeline.call(conn)

        #expect(result.response.status == .unauthorized)
        #expect(result.isHalted)

        let calls = await recorder.calls
        #expect(calls == ["before-halt"])
    }

    @Test("halted pipeline in scope stops downstream execution")
    func test_haltedPipelineInScope_stopsExecution() async throws {
        let flag = ExecutionFlag()

        let protectedPipeline = NamedPipeline {
            HaltingPlug()
        }

        let router = Router {
            scope("/admin", through: protectedPipeline) {
                GET("/secret") { conn in
                    flag.set()
                    return conn.respond(status: .ok, body: .string("secret"))
                }
            }
        }

        let conn = TestConnection.build(path: "/admin/secret")
        let result = try await router(conn)

        #expect(result.response.status == .unauthorized)
        #expect(!flag.wasExecuted)
    }

    // MARK: - Empty pipeline

    @Test("empty pipeline behaves as identity")
    func test_emptyPipeline_identityBehavior() async throws {
        let emptyPipeline = NamedPipeline {}

        let conn = TestConnection.build(path: "/test", body: .buffered(Data("original".utf8)))
        let result = try await emptyPipeline.call(conn)

        // Should pass through unchanged
        #expect(result.request.path == "/test")
        #expect(!result.isHalted)
    }

    @Test("empty pipeline in scope behaves as identity")
    func test_emptyPipelineInScope_identityBehavior() async throws {
        let emptyPipeline = NamedPipeline {}

        let router = Router {
            scope("/api", through: emptyPipeline) {
                GET("/users") { conn in
                    conn.respond(status: .ok, body: .string("users"))
                }
            }
        }

        let conn = TestConnection.build(path: "/api/users")
        let result = try await router(conn)

        #expect(result.response.status == .ok)
        #expect(bodyString(result) == "users")
    }

    // MARK: - ModulePlug conformance

    @Test("named pipeline conforms to ModulePlug")
    func test_modulePlugConformance() async throws {
        let pipeline = NamedPipeline {
            AppendingPlug(label: "M")
        }

        // Test ModulePlug conformance through call(_:)
        let conn = TestConnection.build(path: "/")
        let result = try await pipeline.call(conn)

        #expect(result.assigns["trace"] as? String == "M")
    }

    @Test("asPlug returns correct plug type")
    func test_asPlug_returnsCorrectType() async throws {
        let pipeline = NamedPipeline {
            AppendingPlug(label: "P")
        }

        let plug: Plug = pipeline.asPlug()

        let conn = TestConnection.build(path: "/")
        let result = try await plug(conn)

        #expect(result.assigns["trace"] as? String == "P")
    }

    // MARK: - Sendable conformance

    @Test("named pipeline is sendable")
    func test_sendableConformance() async throws {
        // This test verifies at compile time that NamedPipeline is Sendable
        let pipeline = NamedPipeline {
            AppendingPlug(label: "S")
        }

        // Send to another isolation context
        let result = try await Task {
            let conn = TestConnection.build(path: "/")
            return try await pipeline.call(conn)
        }.value

        #expect(result.assigns["trace"] as? String == "S")
    }

    // MARK: - Complex scenarios

    @Test("nested scopes with different pipelines compose correctly")
    func test_nestedScopes_pipelineComposition() async throws {
        let outerPipeline = NamedPipeline {
            AppendingPlug(label: "outer-")
        }

        let innerPipeline = NamedPipeline {
            AppendingPlug(label: "inner-")
        }

        let router = Router {
            scope("/api", through: outerPipeline) {
                scope("/v2", through: innerPipeline) {
                    GET("/data") { conn in
                        let trace = conn.assigns["trace"] as? String ?? ""
                        return conn.respond(status: .ok, body: .string(trace))
                    }
                }
            }
        }

        let conn = TestConnection.build(path: "/api/v2/data")
        let result = try await router(conn)

        // Nested scopes: outer runs first, then inner, then handler
        #expect(bodyString(result) == "outer-inner-")
    }

    @Test("conditional plugs inside named pipeline")
    func test_conditionalPlugs_insidePipeline() async throws {
        let shouldInclude = true

        let conditionalPipeline = NamedPipeline {
            AppendingPlug(label: "start-")
            if shouldInclude {
                AppendingPlug(label: "conditional-")
            }
            AppendingPlug(label: "end")
        }

        let conn = TestConnection.build(path: "/")
        let result = try await conditionalPipeline.call(conn)

        #expect(result.assigns["trace"] as? String == "start-conditional-end")
    }

    @Test("for loop plugs inside named pipeline")
    func test_forLoopPlugs_insidePipeline() async throws {
        let labels = ["A", "B", "C"]

        let loopingPipeline = NamedPipeline {
            for label in labels {
                AppendingPlug(label: label)
            }
        }

        let conn = TestConnection.build(path: "/")
        let result = try await loopingPipeline.call(conn)

        #expect(result.assigns["trace"] as? String == "ABC")
    }
}

// MARK: - Helpers

private func bodyString(_ conn: Connection) -> String {
    guard case .buffered(let data) = conn.responseBody else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
}
