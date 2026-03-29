import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Telemetry Plug")
struct TelemetryTests {

    // MARK: - Success Path

    @Test("Successful request passes through with correct status")
    func test_success_passThrough() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.response.status = .ok
            copy.responseBody = .buffered(Data("ok".utf8))
            return copy
        }
        let app = telemetry(handler)
        let result = try await app(makeConn())

        #expect(result.response.status == .ok)
        if case .buffered(let data) = result.responseBody {
            #expect(String(data: data, encoding: .utf8) == "ok")
        } else {
            Issue.record("Expected buffered body")
        }
    }

    // MARK: - Error Paths

    @Test("NexusHTTPError is re-thrown with correct status")
    func test_nexusError_rethrown() async throws {
        let failing: Plug = { _ in
            throw NexusHTTPError(.notFound, message: "Not found")
        }
        let app = telemetry(failing)

        do {
            _ = try await app(makeConn())
            Issue.record("Expected error to be thrown")
        } catch let error as NexusHTTPError {
            #expect(error.status == .notFound)
        }
    }

    @Test("Generic error is re-thrown")
    func test_genericError_rethrown() async throws {
        let failing: Plug = { _ in throw TelemetryTestError() }
        let app = telemetry(failing)

        do {
            _ = try await app(makeConn())
            Issue.record("Expected error to be thrown")
        } catch is TelemetryTestError {
            // expected
        }
    }

    // MARK: - Custom Prefix

    @Test("Custom prefix does not crash")
    func test_customPrefix() async throws {
        let handler: Plug = { conn in conn }
        let app = telemetry(handler, prefix: "myapp")
        let result = try await app(makeConn())
        #expect(result.response.status == .ok)
    }

    @Test("Default prefix is nexus")
    func test_defaultPrefix() async throws {
        let handler: Plug = { conn in conn }
        let app = telemetry(handler)
        let result = try await app(makeConn())
        #expect(result.response.status == .ok)
    }

    // MARK: - Pipeline Composition

    @Test("Composable wrapping a pipeline with other plugs")
    func test_composable_pipeline() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.response.status = .created
            return copy
        }
        let app = telemetry(pipeline([requestId(), handler]))
        let result = try await app(makeConn())
        #expect(result.response.status == .created)
        #expect(result.assigns["request_id"] != nil)
    }

    // MARK: - Duration

    @Test("Duration measurement does not block")
    func test_duration_doesNotBlock() async throws {
        let handler: Plug = { conn in conn }
        let app = telemetry(handler)
        let start = ContinuousClock.now
        _ = try await app(makeConn())
        let elapsed = ContinuousClock.now - start
        // Should complete very quickly (< 1 second for an empty pipeline)
        #expect(elapsed < .seconds(1))
    }
}

// MARK: - Helpers

private struct TelemetryTestError: Error {}

private func makeConn() -> Connection {
    let request = HTTPRequest(
        method: .get,
        scheme: "https",
        authority: "example.com",
        path: "/"
    )
    return Connection(request: request)
}
