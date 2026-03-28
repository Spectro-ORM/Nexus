import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Response Content Helpers")
struct ResponseContentTests {

    // MARK: - text()

    @Test("text() sets body and content type")
    func test_text_setsBodyAndContentType() {
        let conn = makeConn().text("hello world")
        #expect(conn.response.status == .ok)
        #expect(conn.response.headerFields[.contentType] == "text/plain; charset=utf-8")
        if case .buffered(let data) = conn.responseBody {
            #expect(String(data: data, encoding: .utf8) == "hello world")
        } else {
            Issue.record("Expected buffered body")
        }
    }

    @Test("text() halts the connection")
    func test_text_halts() {
        let conn = makeConn().text("ok")
        #expect(conn.isHalted)
    }

    @Test("text() with custom status")
    func test_text_customStatus() {
        let conn = makeConn().text("not found", status: .notFound)
        #expect(conn.response.status == .notFound)
        #expect(conn.response.headerFields[.contentType] == "text/plain; charset=utf-8")
    }

    @Test("text() preserves existing response headers")
    func test_text_preservesHeaders() {
        var conn = makeConn()
        conn.response.headerFields[HTTPField.Name("X-Custom")!] = "kept"
        let result = conn.text("hi")
        #expect(result.response.headerFields[HTTPField.Name("X-Custom")!] == "kept")
    }

    // MARK: - xml()

    @Test("xml() sets body and content type")
    func test_xml_setsBodyAndContentType() {
        let xmlString = "<root><item>hello</item></root>"
        let conn = makeConn().xml(xmlString)
        #expect(conn.response.status == .ok)
        #expect(conn.response.headerFields[.contentType] == "application/xml; charset=utf-8")
        if case .buffered(let data) = conn.responseBody {
            #expect(String(data: data, encoding: .utf8) == xmlString)
        } else {
            Issue.record("Expected buffered body")
        }
    }

    @Test("xml() halts the connection")
    func test_xml_halts() {
        let conn = makeConn().xml("<ok/>")
        #expect(conn.isHalted)
    }

    @Test("xml() with custom status")
    func test_xml_customStatus() {
        let conn = makeConn().xml("<error/>", status: .badRequest)
        #expect(conn.response.status == .badRequest)
    }

    // MARK: - data()

    @Test("data() sets body and specified content type")
    func test_data_setsBodyAndContentType() {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47])
        let conn = makeConn().data(pngData, contentType: "image/png")
        #expect(conn.response.status == .ok)
        #expect(conn.response.headerFields[.contentType] == "image/png")
        if case .buffered(let body) = conn.responseBody {
            #expect(body == pngData)
        } else {
            Issue.record("Expected buffered body")
        }
    }

    @Test("data() halts the connection")
    func test_data_halts() {
        let conn = makeConn().data(Data(), contentType: "application/octet-stream")
        #expect(conn.isHalted)
    }

    @Test("data() with custom status")
    func test_data_customStatus() {
        let conn = makeConn().data(Data([0x01]), contentType: "application/protobuf", status: .created)
        #expect(conn.response.status == .created)
        #expect(conn.response.headerFields[.contentType] == "application/protobuf")
    }

    @Test("data() preserves existing response headers")
    func test_data_preservesHeaders() {
        var conn = makeConn()
        conn.response.headerFields[HTTPField.Name("X-Request-Id")!] = "abc"
        let result = conn.data(Data([0x00]), contentType: "application/pdf")
        #expect(result.response.headerFields[HTTPField.Name("X-Request-Id")!] == "abc")
    }

    // MARK: - Consistency with json() and html()

    @Test("All response helpers follow the same pattern")
    func test_allHelpers_consistentBehavior() throws {
        let conn = makeConn()

        let jsonConn = try conn.json(value: ["key": "val"])
        let htmlConn = conn.html("<p>hi</p>")
        let textConn = conn.text("hi")
        let xmlConn = conn.xml("<hi/>")
        let dataConn = conn.data(Data([0x01]), contentType: "image/gif")

        // All halt
        #expect(jsonConn.isHalted)
        #expect(htmlConn.isHalted)
        #expect(textConn.isHalted)
        #expect(xmlConn.isHalted)
        #expect(dataConn.isHalted)

        // All set content type
        #expect(jsonConn.response.headerFields[.contentType] == "application/json")
        #expect(htmlConn.response.headerFields[.contentType] == "text/html; charset=utf-8")
        #expect(textConn.response.headerFields[.contentType] == "text/plain; charset=utf-8")
        #expect(xmlConn.response.headerFields[.contentType] == "application/xml; charset=utf-8")
        #expect(dataConn.response.headerFields[.contentType] == "image/gif")

        // All default to 200
        #expect(jsonConn.response.status == .ok)
        #expect(htmlConn.response.status == .ok)
        #expect(textConn.response.status == .ok)
        #expect(xmlConn.response.status == .ok)
        #expect(dataConn.response.status == .ok)
    }
}

// MARK: - Helpers

private func makeConn() -> Connection {
    Connection(request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"))
}
