import Testing
import Foundation
import HTTPTypes
@testable import Nexus

@Suite("JSONValue")
struct JSONValueTests {

    private func makeConnection(json: String) -> Connection {
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request, requestBody: .buffered(Data(json.utf8)))
    }

    @Test("test_jsonBody_parsesValidJSON")
    func test_jsonBody_parsesValidJSON() throws {
        let conn = makeConnection(json: #"{"name":"donut"}"#)
        let json = try conn.jsonBody()
        let name = try json.string("name")
        #expect(name == "donut")
    }

    @Test("test_jsonBody_throwsForEmptyBody")
    func test_jsonBody_throwsForEmptyBody() {
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request)
        #expect(throws: NexusHTTPError.self) {
            try conn.jsonBody()
        }
    }

    @Test("test_jsonBody_throwsForInvalidJSON")
    func test_jsonBody_throwsForInvalidJSON() {
        let conn = makeConnection(json: "not json")
        #expect(throws: NexusHTTPError.self) {
            try conn.jsonBody()
        }
    }

    @Test("test_jsonValue_string_returnsStringValue")
    func test_jsonValue_string_returnsStringValue() throws {
        let json = try makeConnection(json: #"{"event":"click"}"#).jsonBody()
        #expect(try json.string("event") == "click")
    }

    @Test("test_jsonValue_int_returnsIntValue")
    func test_jsonValue_int_returnsIntValue() throws {
        let json = try makeConnection(json: #"{"count":42}"#).jsonBody()
        #expect(try json.int("count") == 42)
    }

    @Test("test_jsonValue_double_returnsDoubleValue")
    func test_jsonValue_double_returnsDoubleValue() throws {
        let json = try makeConnection(json: #"{"price":9.99}"#).jsonBody()
        #expect(try json.double("price") == 9.99)
    }

    @Test("test_jsonValue_bool_returnsBoolValue")
    func test_jsonValue_bool_returnsBoolValue() throws {
        let json = try makeConnection(json: #"{"active":true}"#).jsonBody()
        #expect(try json.bool("active") == true)
    }

    @Test("test_jsonValue_array_returnsArray")
    func test_jsonValue_array_returnsArray() throws {
        let json = try makeConnection(json: #"{"tags":["a","b","c"]}"#).jsonBody()
        let tags = try json.array("tags")
        #expect(tags.count == 3)
        #expect(try tags[0].stringValue() == "a")
    }

    @Test("test_jsonValue_object_returnsNestedObject")
    func test_jsonValue_object_returnsNestedObject() throws {
        let json = try makeConnection(json: #"{"user":{"name":"alice"}}"#).jsonBody()
        let user = try json.object("user")
        #expect(try user.string("name") == "alice")
    }

    @Test("test_jsonValue_missingKey_throwsBadRequest")
    func test_jsonValue_missingKey_throwsBadRequest() throws {
        let json = try makeConnection(json: #"{"name":"test"}"#).jsonBody()
        #expect(throws: NexusHTTPError.self) {
            try json.string("missing")
        }
    }

    @Test("test_jsonValue_wrongType_throwsBadRequest")
    func test_jsonValue_wrongType_throwsBadRequest() throws {
        let json = try makeConnection(json: #"{"name":123}"#).jsonBody()
        #expect(throws: NexusHTTPError.self) {
            try json.string("name")
        }
    }
}
