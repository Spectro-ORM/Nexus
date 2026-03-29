import Testing
@testable import Nexus
import NexusTest

// @unchecked Sendable: only used in single-threaded test context
private final class LockedFlag: @unchecked Sendable {
    private(set) var value = false
    func set() { value = true }
}
private final class LockedError: @unchecked Sendable {
    private(set) var captured: Error?
    func set(_ error: Error) { captured = error }
}

@Suite("onError Plug")
struct OnErrorTests {

    struct InfraError: Error, Equatable {}
    struct OtherError: Error, Equatable {}

    // MARK: - Basic catch

    @Test("onError catches thrown error and calls handler")
    func test_onError_throwingPlug_callsHandler() async throws {
        let app = onError({ _ in throw InfraError() }) { conn, _ in
            conn.respond(status: .internalServerError, body: .string("caught"))
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .internalServerError)
        #expect(result.isHalted)
    }

    @Test("onError handler receives the original connection")
    func test_onError_handler_receivesConnection() async throws {
        let app = onError(
            { conn in
                let _ = conn.assign(key: "before", value: "yes")
                throw InfraError()
            }
        ) { conn, _ in
            conn.assign(key: "handler_saw", value: conn.assigns["before"] as? String ?? "no")
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        // Connection passed to handler is the input conn (before the throw)
        #expect(result.assigns["handler_saw"] as? String == "no")
    }

    @Test("onError handler receives the thrown error")
    func test_onError_handler_receivesError() async throws {
        let captured = LockedError()
        let app = onError({ _ in throw InfraError() }) { conn, error in
            captured.set(error)
            return conn.respond(status: .internalServerError)
        }
        let conn = TestConnection.build(path: "/")
        _ = try await app(conn)
        #expect(captured.captured is InfraError)
    }

    // MARK: - No error passthrough

    @Test("onError does not interfere when no error is thrown")
    func test_onError_noThrow_passesThroughUnchanged() async throws {
        let inner: Plug = { conn in
            conn.assign(key: "ran", value: true)
        }
        let app = onError(inner) { conn, _ in
            conn.respond(status: .internalServerError)
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.assigns["ran"] as? Bool == true)
        #expect(!result.isHalted)
    }

    // MARK: - NexusHTTPError

    @Test("onError catches NexusHTTPError")
    func test_onError_nexusHTTPError_isCaught() async throws {
        let app = onError({ _ in throw NexusHTTPError(.notFound) }) { conn, error in
            if let httpError = error as? NexusHTTPError {
                return conn.respond(status: httpError.status, body: .string("mapped"))
            }
            return conn.respond(status: .internalServerError)
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .notFound)
    }

    // MARK: - Nested handlers

    @Test("inner onError catches first, outer is not invoked")
    func test_onError_nested_innerCatchesFirst() async throws {
        let outerCalled = LockedFlag()
        let innerApp = onError({ _ in throw InfraError() }) { conn, _ in
            conn.respond(status: .serviceUnavailable, body: .string("inner"))
        }
        let outerApp = onError(innerApp) { conn, _ in
            outerCalled.set()
            return conn.respond(status: .internalServerError, body: .string("outer"))
        }
        let conn = TestConnection.build(path: "/")
        let result = try await outerApp(conn)
        #expect(result.response.status == .serviceUnavailable)
        #expect(!outerCalled.value)
    }

    @Test("outer onError catches when inner does not")
    func test_onError_nested_outerCatchesIfInnerMisses() async throws {
        let innerApp = onError(
            { _ in throw InfraError() }
        ) { conn, error in
            guard error is OtherError else { throw error }
            return conn.respond(status: .badGateway)
        }
        let outerApp = onError(innerApp) { conn, _ in
            conn.respond(status: .internalServerError, body: .string("outer caught"))
        }
        let conn = TestConnection.build(path: "/")
        let result = try await outerApp(conn)
        #expect(result.response.status == .internalServerError)
    }

    // MARK: - Works with pipeline

    @Test("onError wraps a multi-plug pipeline")
    func test_onError_wrappingPipeline_catchesFromAnyPlug() async throws {
        let step1: Plug = { conn in conn.assign(key: "step1", value: true) }
        let step2: Plug = { _ in throw InfraError() }
        let step3: Plug = { conn in conn.assign(key: "step3", value: true) }

        let app = onError(pipeline([step1, step2, step3])) { conn, _ in
            conn.respond(status: .internalServerError, body: .string("error"))
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .internalServerError)
    }

    // MARK: - Backward compatibility

    @Test("rescueErrors still works alongside onError")
    func test_rescueErrors_stillWorks_noConflict() async throws {
        let app = rescueErrors({ _ in throw NexusHTTPError(.forbidden) })
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .forbidden)
        #expect(result.isHalted)
    }
}
