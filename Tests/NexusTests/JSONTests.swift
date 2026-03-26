import Testing
import Foundation
import HTTPTypes
@testable import Nexus

// MARK: - Decode Tests

@Suite("JSON Decoding")
struct JSONDecodingTests {

    private func makeConnection(body: RequestBody = .empty) -> Connection {
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request, requestBody: body)
    }

    struct Payload: Decodable, Sendable, Equatable {
        let name: String
        let count: Int
    }

    @Test("test_connection_decode_decodesValidJSON")
    func test_connection_decode_decodesValidJSON() throws {
        let json = #"{"name":"donut","count":3}"#
        let conn = makeConnection(body: .buffered(Data(json.utf8)))
        let result = try conn.decode(as: Payload.self)
        #expect(result.name == "donut")
        #expect(result.count == 3)
    }

    @Test("test_connection_decode_throwsForEmptyBody")
    func test_connection_decode_throwsForEmptyBody() {
        let conn = makeConnection(body: .empty)
        #expect(throws: NexusHTTPError.self) {
            try conn.decode(as: Payload.self)
        }
    }

    @Test("test_connection_decode_throwsForInvalidJSON")
    func test_connection_decode_throwsForInvalidJSON() {
        let conn = makeConnection(body: .buffered(Data("not json".utf8)))
        #expect(throws: NexusHTTPError.self) {
            try conn.decode(as: Payload.self)
        }
    }

    @Test("test_connection_decode_errorIsBadRequest")
    func test_connection_decode_errorIsBadRequest() {
        let conn = makeConnection(body: .empty)
        do {
            _ = try conn.decode(as: Payload.self)
            Issue.record("Expected NexusHTTPError")
        } catch let error as NexusHTTPError {
            #expect(error.status == .badRequest)
        } catch {
            Issue.record("Expected NexusHTTPError, got \(error)")
        }
    }

    @Test("test_connection_decode_usesCustomDecoder")
    func test_connection_decode_usesCustomDecoder() throws {
        struct SnakePayload: Decodable, Sendable {
            let userName: String
        }
        let json = #"{"user_name":"alice"}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let conn = makeConnection(body: .buffered(Data(json.utf8)))
        let result = try conn.decode(as: SnakePayload.self, decoder: decoder)
        #expect(result.userName == "alice")
    }
}

// MARK: - JSON Response Tests

@Suite("JSON Response")
struct JSONResponseTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request)
    }

    struct Item: Encodable, Sendable {
        let id: Int
        let name: String
    }

    @Test("test_connection_json_setsStatusAndBody")
    func test_connection_json_setsStatusAndBody() throws {
        let conn = try makeConnection().json(status: .created, value: Item(id: 1, name: "donut"))
        #expect(conn.response.status == .created)
        if case .buffered(let data) = conn.responseBody {
            let str = String(data: data, encoding: .utf8) ?? ""
            #expect(str.contains("\"id\":1") || str.contains("\"id\" : 1"))
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }

    @Test("test_connection_json_setsContentTypeHeader")
    func test_connection_json_setsContentTypeHeader() throws {
        let conn = try makeConnection().json(value: Item(id: 1, name: "test"))
        #expect(conn.response.headerFields[.contentType] == "application/json")
    }

    @Test("test_connection_json_preservesExistingHeaders")
    func test_connection_json_preservesExistingHeaders() throws {
        var base = makeConnection()
        base.response.headerFields[.server] = "Nexus"
        let conn = try base.json(value: Item(id: 1, name: "test"))
        #expect(conn.response.headerFields[.server] == "Nexus")
        #expect(conn.response.headerFields[.contentType] == "application/json")
    }

    @Test("test_connection_json_haltsConnection")
    func test_connection_json_haltsConnection() throws {
        let conn = try makeConnection().json(value: Item(id: 1, name: "test"))
        #expect(conn.isHalted == true)
    }

    @Test("test_connection_json_defaultsToOKStatus")
    func test_connection_json_defaultsToOKStatus() throws {
        let conn = try makeConnection().json(value: Item(id: 1, name: "test"))
        #expect(conn.response.status == .ok)
    }

    @Test("test_connection_json_encodesNestedStructures")
    func test_connection_json_encodesNestedStructures() throws {
        struct Wrapper: Encodable, Sendable {
            let items: [Item]
        }
        let conn = try makeConnection().json(
            value: Wrapper(items: [Item(id: 1, name: "a"), Item(id: 2, name: "b")])
        )
        if case .buffered(let data) = conn.responseBody {
            let str = String(data: data, encoding: .utf8) ?? ""
            #expect(str.contains("items"))
        } else {
            Issue.record("Expected .buffered responseBody")
        }
    }
}
