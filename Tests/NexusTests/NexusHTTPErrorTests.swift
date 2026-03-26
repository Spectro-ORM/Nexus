import Testing
import HTTPTypes
@testable import Nexus

@Suite("NexusHTTPError")
struct NexusHTTPErrorTests {

    @Test("test_nexusHTTPError_storesStatusAndMessage")
    func test_nexusHTTPError_storesStatusAndMessage() {
        let error = NexusHTTPError(.notFound, message: "User not found")
        #expect(error.status == .notFound)
        #expect(error.message == "User not found")
    }

    @Test("test_nexusHTTPError_defaultsToEmptyMessage")
    func test_nexusHTTPError_defaultsToEmptyMessage() {
        let error = NexusHTTPError(.forbidden)
        #expect(error.message == "")
    }
}

@Suite("rescueErrors")
struct RescueErrorsTests {

    private func makeConnection(path: String = "/") -> Connection {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: path)
        return Connection(request: request)
    }

    @Test("test_rescueErrors_noError_passesThroughNormally")
    func test_rescueErrors_noError_passesThroughNormally() async throws {
        let plug: Plug = { conn in conn.respond(status: .ok, body: .string("OK")) }
        let app = rescueErrors(plug)
        let result = try await app(makeConnection())
        #expect(result.response.status == .ok)
    }

    @Test("test_rescueErrors_catchesNexusHTTPError_returnsHaltedResponse")
    func test_rescueErrors_catchesNexusHTTPError_returnsHaltedResponse() async throws {
        let plug: Plug = { _ in throw NexusHTTPError(.notFound, message: "Not here") }
        let app = rescueErrors(plug)
        let result = try await app(makeConnection())
        #expect(result.isHalted == true)
    }

    @Test("test_rescueErrors_setsCorrectStatusCode")
    func test_rescueErrors_setsCorrectStatusCode() async throws {
        let plug: Plug = { _ in throw NexusHTTPError(.forbidden, message: "Denied") }
        let app = rescueErrors(plug)
        let result = try await app(makeConnection())
        #expect(result.response.status == .forbidden)
    }

    @Test("test_rescueErrors_includesMessageInBody")
    func test_rescueErrors_includesMessageInBody() async throws {
        let plug: Plug = { _ in throw NexusHTTPError(.badRequest, message: "Invalid input") }
        let app = rescueErrors(plug)
        let result = try await app(makeConnection())
        if case .buffered(let data) = result.responseBody {
            #expect(String(data: data, encoding: .utf8) == "Invalid input")
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }

    @Test("test_rescueErrors_emptyMessage_returnsEmptyBody")
    func test_rescueErrors_emptyMessage_returnsEmptyBody() async throws {
        let plug: Plug = { _ in throw NexusHTTPError(.unauthorized) }
        let app = rescueErrors(plug)
        let result = try await app(makeConnection())
        #expect(result.response.status == .unauthorized)
        if case .empty = result.responseBody { } else {
            Issue.record("Expected .empty responseBody")
        }
    }

    @Test("test_rescueErrors_nonNexusError_propagates")
    func test_rescueErrors_nonNexusError_propagates() async {
        struct InfraError: Error {}
        let plug: Plug = { _ in throw InfraError() }
        let app = rescueErrors(plug)
        await #expect(throws: InfraError.self) {
            try await app(makeConnection())
        }
    }

    @Test("test_rescueErrors_preservesOriginalConnectionHeaders")
    func test_rescueErrors_preservesOriginalConnectionHeaders() async throws {
        let failPlug: Plug = { _ in throw NexusHTTPError(.notFound, message: "gone") }
        let app = rescueErrors(failPlug)
        // Set a header on the connection before it enters rescueErrors
        var conn = makeConnection()
        conn.response.headerFields[.server] = "Nexus"
        let result = try await app(conn)
        #expect(result.response.status == .notFound)
        #expect(result.response.headerFields[.server] == "Nexus")
    }
}
