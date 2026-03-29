import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("prefersHTML")
struct PrefersHTMLTests {

    // MARK: - Missing Accept Header

    @Test("Missing Accept header returns true")
    func test_prefersHTML_missingAccept_returnsTrue() {
        let conn = makeConn(accept: nil)
        #expect(conn.prefersHTML == true)
    }

    // MARK: - Wildcard

    @Test("Accept: */* returns true")
    func test_prefersHTML_wildcard_returnsTrue() {
        let conn = makeConn(accept: "*/*")
        #expect(conn.prefersHTML == true)
    }

    @Test("Accept: */* with no JSON returns true")
    func test_prefersHTML_wildcardNoJSON_returnsTrue() {
        let conn = makeConn(accept: "*/*; q=0.8")
        #expect(conn.prefersHTML == true)
    }

    // MARK: - Browser-like Headers

    @Test("Browser Accept with text/html first returns true")
    func test_prefersHTML_browserAccept_returnsTrue() {
        let conn = makeConn(accept: "text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8")
        #expect(conn.prefersHTML == true)
    }

    @Test("text/html before application/json returns true")
    func test_prefersHTML_htmlBeforeJSON_returnsTrue() {
        let conn = makeConn(accept: "text/html, application/json")
        #expect(conn.prefersHTML == true)
    }

    // MARK: - API Client Headers

    @Test("application/json before text/html returns false")
    func test_prefersHTML_jsonBeforeHTML_returnsFalse() {
        let conn = makeConn(accept: "application/json, text/html")
        #expect(conn.prefersHTML == false)
    }

    @Test("application/json only returns false")
    func test_prefersHTML_jsonOnly_returnsFalse() {
        let conn = makeConn(accept: "application/json")
        #expect(conn.prefersHTML == false)
    }

    @Test("application/json with wildcard returns false")
    func test_prefersHTML_jsonWithWildcard_returnsFalse() {
        let conn = makeConn(accept: "application/json, */*")
        #expect(conn.prefersHTML == false)
    }

    // MARK: - text/html Only

    @Test("text/html only returns true")
    func test_prefersHTML_htmlOnly_returnsTrue() {
        let conn = makeConn(accept: "text/html")
        #expect(conn.prefersHTML == true)
    }

    // MARK: - respondTo Integration

    @Test("respondTo returns HTML when Accept is missing")
    func test_respondTo_missingAccept_returnsHTML() throws {
        let conn = makeConn(accept: nil)
        let result = try conn.respondTo(
            html: { conn.html("<p>hello</p>") },
            json: { try conn.json(value: ["msg": "hello"]) }
        )
        #expect(result.response.headerFields[.contentType] == "text/html; charset=utf-8")
    }

    @Test("respondTo returns HTML for */*")
    func test_respondTo_wildcard_returnsHTML() throws {
        let conn = makeConn(accept: "*/*")
        let result = try conn.respondTo(
            html: { conn.html("<p>hi</p>") },
            json: { try conn.json(value: ["msg": "hi"]) }
        )
        #expect(result.response.headerFields[.contentType] == "text/html; charset=utf-8")
    }

    @Test("respondTo returns JSON for application/json")
    func test_respondTo_json_returnsJSON() throws {
        let conn = makeConn(accept: "application/json")
        let result = try conn.respondTo(
            html: { conn.html("<p>hi</p>") },
            json: { try conn.json(value: ["msg": "hi"]) }
        )
        #expect(result.response.headerFields[.contentType] == "application/json")
    }

    // MARK: - Edge Cases

    @Test("Empty Accept header returns true")
    func test_prefersHTML_emptyAccept_returnsTrue() {
        let conn = makeConn(accept: "")
        #expect(conn.prefersHTML == true)
    }

    @Test("Unrelated content type returns true (HTML default)")
    func test_prefersHTML_unrelatedType_returnsTrue() {
        let conn = makeConn(accept: "image/png")
        #expect(conn.prefersHTML == true)
    }
}

// MARK: - Helpers

private func makeConn(accept: String?) -> Connection {
    var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
    if let accept {
        request.headerFields[.accept] = accept
    }
    return Connection(request: request)
}
