import Testing
import Foundation
import HTTPTypes
@testable import Nexus
import NexusTest

@Suite("Test Helpers (Connection.make)")
struct TestHelpersTests {

    // MARK: - Connection.make()

    @Test("Connection.make defaults to GET /")
    func test_make_defaults_getRoot() {
        let conn = Connection.make()
        #expect(conn.request.method == .get)
        #expect(conn.request.path == "/")
    }

    @Test("Connection.make sets method and path")
    func test_make_methodAndPath() {
        let conn = Connection.make(method: .post, path: "/users")
        #expect(conn.request.method == .post)
        #expect(conn.request.path == "/users")
    }

    @Test("Connection.make sets custom headers")
    func test_make_customHeaders() {
        var headers = HTTPFields()
        headers[.authorization] = "Bearer token"
        let conn = Connection.make(headers: headers)
        #expect(conn.request.headerFields[.authorization] == "Bearer token")
    }

    @Test("Connection.make sets body")
    func test_make_body() {
        let bodyData = Data("hello".utf8)
        let conn = Connection.make(body: .buffered(bodyData))
        if case .buffered(let data) = conn.requestBody {
            #expect(data == bodyData)
        } else {
            Issue.record("Expected buffered body")
        }
    }

    @Test("Connection.make starts with empty response")
    func test_make_emptyResponse() {
        let conn = Connection.make()
        #expect(conn.response.status == .ok)
        #expect(!conn.isHalted)
        if case .empty = conn.responseBody {
            // pass
        } else {
            Issue.record("Expected empty response body")
        }
    }

    // MARK: - Connection.makeJSON()

    @Test("Connection.makeJSON sets JSON content-type")
    func test_makeJSON_setsContentType() {
        let conn = Connection.makeJSON(json: #"{"key":"val"}"#)
        #expect(conn.request.headerFields[.contentType] == "application/json")
    }

    @Test("Connection.makeJSON buffers the body")
    func test_makeJSON_buffersBody() {
        let json = #"{"id":1}"#
        let conn = Connection.makeJSON(json: json)
        if case .buffered(let data) = conn.requestBody {
            #expect(String(data: data, encoding: .utf8) == json)
        } else {
            Issue.record("Expected buffered body")
        }
    }

    @Test("Connection.makeJSON defaults to POST")
    func test_makeJSON_defaultsToPost() {
        let conn = Connection.makeJSON(json: "{}")
        #expect(conn.request.method == .post)
    }

    // MARK: - Connection.makeForm()

    @Test("Connection.makeForm sets form content-type")
    func test_makeForm_setsContentType() {
        let conn = Connection.makeForm(form: "name=Alice")
        #expect(conn.request.headerFields[.contentType] == "application/x-www-form-urlencoded")
    }

    @Test("Connection.makeForm buffers encoded body")
    func test_makeForm_buffersBody() {
        let form = "user=alice&pass=secret"
        let conn = Connection.makeForm(form: form)
        if case .buffered(let data) = conn.requestBody {
            #expect(String(data: data, encoding: .utf8) == form)
        } else {
            Issue.record("Expected buffered body")
        }
    }

    // MARK: - Equivalence with TestConnection

    @Test("Connection.make is equivalent to TestConnection.build")
    func test_make_equivalentTo_testConnectionBuild() {
        let via_make = Connection.make(method: .put, path: "/test")
        let via_build = TestConnection.build(method: .put, path: "/test")
        #expect(via_make.request.method == via_build.request.method)
        #expect(via_make.request.path == via_build.request.path)
    }

    // MARK: - Use in tests

    @Test("Connection.make works in an async plug test")
    func test_make_worksInPlugTest() async throws {
        let echo: Plug = { conn in
            conn.assign(key: "path", value: conn.request.path ?? "")
        }
        let conn = Connection.make(path: "/hello")
        let result = try await echo(conn)
        #expect(result.assigns["path"] as? String == "/hello")
    }
}
