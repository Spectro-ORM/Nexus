import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import Nexus
import NexusHummingbird
import Testing

@Suite("NexusHummingbirdAdapter")
struct HummingbirdAdapterTests {

    // MARK: - Helpers

    /// Builds an `Application` from a plug and runs the test closure against it
    /// using the `.router` test framework (no live server).
    private func withApp(
        plug: @escaping Plug,
        _ test: @Sendable (any TestClientProtocol) async throws -> Void
    ) async throws {
        let adapter = NexusHummingbirdAdapter(plug: plug)
        let app = Application(responder: adapter)
        try await app.test(.router) { client in
            try await test(client)
        }
    }

    // MARK: - Tests

    @Test func test_adapter_passthrough_returnsOK() async throws {
        let plug: Plug = { conn in conn }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .ok)
        }
    }

    @Test func test_adapter_customStatus_returnsStatus() async throws {
        let plug: Plug = { conn in
            conn.respond(status: .created)
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .post,
                headers: [:],
                body: nil
            )
            #expect(response.status == .created)
        }
    }

    @Test func test_adapter_responseBody_returnsBufferedBody() async throws {
        let plug: Plug = { conn in
            conn.respond(
                status: .ok,
                body: .string("hello nexus")
            )
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .ok)
            #expect(String(buffer: response.body) == "hello nexus")
        }
    }

    @Test func test_adapter_requestBody_receivedByPlug() async throws {
        actor BodyCapture {
            var captured: Nexus.RequestBody?
            func set(_ body: Nexus.RequestBody) { captured = body }
        }

        let capture = BodyCapture()
        let plug: Plug = { conn in
            await capture.set(conn.requestBody)
            return conn.respond(status: .ok)
        }

        try await withApp(plug: plug) { client in
            let payload = "test payload"
            let payloadData = Data(payload.utf8)
            let response = try await client.executeRequest(
                uri: "/upload",
                method: .post,
                headers: [.contentType: "text/plain"],
                body: .init(bytes: payloadData)
            )
            #expect(response.status == .ok)

            let body = await capture.captured
            guard case .buffered(let data) = body else {
                Issue.record("Expected .buffered body, got \(String(describing: body))")
                return
            }
            #expect(String(data: data, encoding: .utf8) == payload)
        }
    }

    @Test func test_adapter_haltedConnection_returnsHaltedResponse() async throws {
        let plug: Plug = { conn in
            conn.respond(
                status: .forbidden,
                body: .string("access denied")
            )
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/secret",
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .forbidden)
            #expect(String(buffer: response.body) == "access denied")
        }
    }

    @Test func test_adapter_plugThrows_returns500() async throws {
        struct InfrastructureError: Error {}

        let plug: Plug = { _ in
            throw InfrastructureError()
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .internalServerError)
        }
    }

    @Test func test_adapter_responseHeaders_preserved() async throws {
        let plug: Plug = { conn in
            var copy = conn.respond(status: .ok, body: .string("{}"))
            copy.response = HTTPResponse(
                status: .ok,
                headerFields: [
                    .contentType: "application/json",
                    HTTPField.Name("X-Custom")!: "nexus",
                ]
            )
            return copy
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/json")
            #expect(response.headers[HTTPField.Name("X-Custom")!] == "nexus")
        }
    }

    @Test func test_adapter_beforeSend_callbacksRunBeforeSerialization() async throws {
        let plug: Plug = { conn in
            conn
                .registerBeforeSend { c in
                    var copy = c
                    copy.response.headerFields[HTTPField.Name("X-Before-Send")!] = "applied"
                    return copy
                }
                .respond(status: .ok, body: .string("hello"))
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .ok)
            #expect(response.headers[HTTPField.Name("X-Before-Send")!] == "applied")
            #expect(String(buffer: response.body) == "hello")
        }
    }

    @Test func test_adapter_emptyBody_returnsEmptyResponse() async throws {
        let plug: Plug = { conn in
            conn.respond(status: .noContent)
        }

        try await withApp(plug: plug) { client in
            let response = try await client.executeRequest(
                uri: "/",
                method: .delete,
                headers: [:],
                body: nil
            )
            #expect(response.status == .noContent)
            #expect(response.body.readableBytes == 0)
        }
    }
}
