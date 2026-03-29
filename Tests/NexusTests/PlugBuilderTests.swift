import Testing
@testable import Nexus
import NexusTest

// @unchecked Sendable: only used in single-threaded test context
private final class LockedFlag: @unchecked Sendable {
    private(set) var value = false
    func set() { value = true }
}

@Suite("PlugBuilder")
struct PlugBuilderTests {

    // MARK: - buildPipeline basic

    @Test("buildPipeline with single plug works")
    func test_buildPipeline_single_runs() async throws {
        let app = buildPipeline {
            { conn in conn.assign(key: "ran", value: true) } as Plug
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["ran"] as? Bool == true)
    }

    @Test("buildPipeline executes plugs in order")
    func test_buildPipeline_multiple_executesInOrder() async throws {
        let app = buildPipeline {
            { conn in conn.assign(key: "a", value: 1) } as Plug
            { conn in conn.assign(key: "b", value: 2) } as Plug
            { conn in conn.assign(key: "c", value: 3) } as Plug
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["a"] as? Int == 1)
        #expect(result.assigns["b"] as? Int == 2)
        #expect(result.assigns["c"] as? Int == 3)
    }

    // MARK: - ModulePlug in PlugPipeline

    struct MarkerPlug: ModulePlug {
        let key: String
        func call(_ connection: Connection) async throws -> Connection {
            connection.assign(key: key, value: true)
        }
    }

    @Test("buildPipeline accepts ModulePlug instances directly")
    func test_buildPipeline_modulePlug_convertsAutomatically() async throws {
        let app = buildPipeline {
            MarkerPlug(key: "module_ran")
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["module_ran"] as? Bool == true)
    }

    @Test("buildPipeline mixes Plug and ModulePlug")
    func test_buildPipeline_mixed_plugAndModule() async throws {
        let app = buildPipeline {
            { conn in conn.assign(key: "fn_ran", value: true) } as Plug
            MarkerPlug(key: "module_ran")
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["fn_ran"] as? Bool == true)
        #expect(result.assigns["module_ran"] as? Bool == true)
    }

    // MARK: - ConfigurablePlug in PlugPipeline

    struct LabelPlug: ConfigurablePlug {
        let label: String
        init(options: String) { label = options }
        func call(_ connection: Connection) async throws -> Connection {
            connection.assign(key: "label", value: label)
        }
    }

    @Test("buildPipeline accepts ConfigurablePlug instances directly")
    func test_buildPipeline_configurablePlug_convertsAutomatically() async throws {
        let app = buildPipeline {
            try! LabelPlug(options: "hello")
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["label"] as? String == "hello")
    }

    // MARK: - Conditional plugs

    @Test("buildPipeline supports if-then optional plug")
    func test_buildPipeline_conditionalTrue_plugIncluded() async throws {
        let includeMarker = true
        let app = buildPipeline {
            if includeMarker {
                MarkerPlug(key: "conditional")
            }
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["conditional"] as? Bool == true)
    }

    @Test("buildPipeline supports if-then optional plug omitted")
    func test_buildPipeline_conditionalFalse_plugOmitted() async throws {
        let includeMarker = false
        let app = buildPipeline {
            if includeMarker {
                MarkerPlug(key: "conditional")
            }
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["conditional"] == nil)
    }

    @Test("buildPipeline supports if-else plug selection")
    func test_buildPipeline_ifElse_correctBranchRuns() async throws {
        let isProd = true
        let app = buildPipeline {
            if isProd {
                MarkerPlug(key: "prod")
            } else {
                MarkerPlug(key: "dev")
            }
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["prod"] as? Bool == true)
        #expect(result.assigns["dev"] == nil)
    }

    // MARK: - Halt propagation

    @Test("buildPipeline stops at halted connection")
    func test_buildPipeline_halt_stopsPipeline() async throws {
        let secondRan = LockedFlag()
        let app = buildPipeline {
            { conn in conn.respond(status: .unauthorized) } as Plug
            { conn in
                secondRan.set()
                return conn
            } as Plug
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .unauthorized)
        #expect(!secondRan.value)
    }

    // MARK: - Equivalent to pipeline([...])

    @Test("buildPipeline and pipeline produce equivalent results")
    func test_buildPipeline_equivalentTo_pipeline() async throws {
        let plug1: Plug = { conn in conn.assign(key: "x", value: 1) }
        let plug2: Plug = { conn in conn.assign(key: "y", value: 2) }

        let viaBuilder = buildPipeline { plug1; plug2 }
        let viaFunction = pipeline([plug1, plug2])

        let conn = TestConnection.build(path: "/")
        let r1 = try await viaBuilder(conn)
        let r2 = try await viaFunction(conn)
        #expect(r1.assigns["x"] as? Int == r2.assigns["x"] as? Int)
        #expect(r1.assigns["y"] as? Int == r2.assigns["y"] as? Int)
    }
}
