import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Body Parser Plug")
struct BodyParserTests {

    // MARK: - JSON Parsing

    @Test("Parses JSON body into parsedJSON")
    func test_bodyParser_json_parsesParsedJSON() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/json",
            body: Data(#"{"name":"Alice","age":30}"#.utf8)
        ))
        let json = conn.parsedJSON
        #expect(json != nil)
        #expect(try json?.string("name") == "Alice")
        #expect(try json?.int("age") == 30)
    }

    @Test("JSON parsing does not set bodyParams")
    func test_bodyParser_json_doesNotSetBodyParams() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/json",
            body: Data(#"{"key":"val"}"#.utf8)
        ))
        #expect(conn.bodyParams.isEmpty)
    }

    // MARK: - URL-Encoded Form Parsing

    @Test("Parses URL-encoded body into bodyParams")
    func test_bodyParser_urlEncoded_parsesBodyParams() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/x-www-form-urlencoded",
            body: Data("name=Bob&email=bob%40example.com".utf8)
        ))
        #expect(conn.bodyParams["name"] == "Bob")
        #expect(conn.bodyParams["email"] == "bob@example.com")
    }

    @Test("URL-encoded parsing does not set parsedJSON")
    func test_bodyParser_urlEncoded_doesNotSetJSON() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/x-www-form-urlencoded",
            body: Data("key=val".utf8)
        ))
        #expect(conn.parsedJSON == nil)
    }

    // MARK: - Multipart Parsing

    @Test("Parses multipart body into bodyParams and uploadedFiles")
    func test_bodyParser_multipart_parsesFieldsAndFiles() async throws {
        let boundary = "testboundary"
        let body = buildMultipartBody(boundary: boundary, parts: [
            ("Content-Disposition: form-data; name=\"title\"\r\n\r\nMy Doc", nil),
            ("Content-Disposition: form-data; name=\"file\"; filename=\"doc.txt\"\r\nContent-Type: text/plain\r\n\r\nfile content", nil),
        ])
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "multipart/form-data; boundary=\(boundary)",
            body: body
        ))
        #expect(conn.bodyParams["title"] == "My Doc")
        let file = conn.uploadedFile("file")
        #expect(file?.filename == "doc.txt")
        #expect(file?.data == Data("file content".utf8))
    }

    // MARK: - GET Passthrough

    @Test("GET requests pass through without parsing")
    func test_bodyParser_getRequest_passesThrough() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .get,
            contentType: "application/json",
            body: Data(#"{"key":"val"}"#.utf8)
        ))
        #expect(conn.parsedJSON == nil)
        #expect(conn.bodyParams.isEmpty)
    }

    // MARK: - Unknown Content-Type

    @Test("Unknown content type passes through")
    func test_bodyParser_unknownContentType_passesThrough() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/xml",
            body: Data("<root/>".utf8)
        ))
        #expect(conn.parsedJSON == nil)
        #expect(conn.bodyParams.isEmpty)
        #expect(!conn.isHalted)
    }

    // MARK: - Missing Content-Type

    @Test("Missing content type passes through")
    func test_bodyParser_missingContentType_passesThrough() async throws {
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        let conn = Connection(request: request, requestBody: .buffered(Data("data".utf8)))
        let result = try await bodyParser()(conn)
        #expect(result.parsedJSON == nil)
        #expect(!result.isHalted)
    }

    // MARK: - Oversized Body

    @Test("Oversized body returns 413")
    func test_bodyParser_oversizedBody_returns413() async throws {
        let config = BodyParserConfig(maxBodySize: 10)
        let conn = try await bodyParser(config)(makeConn(
            method: .post,
            contentType: "application/json",
            body: Data(String(repeating: "x", count: 20).utf8)
        ))
        #expect(conn.isHalted)
        #expect(conn.response.status == .contentTooLarge)
    }

    // MARK: - Idempotent

    @Test("Running twice does not re-parse")
    func test_bodyParser_idempotent() async throws {
        let plug = bodyParser()
        let conn = makeConn(
            method: .post,
            contentType: "application/x-www-form-urlencoded",
            body: Data("key=value".utf8)
        )
        let first = try await plug(conn)
        #expect(first.bodyParams["key"] == "value")

        // Run again — should be a no-op
        let second = try await plug(first)
        #expect(second.bodyParams["key"] == "value")
    }

    // MARK: - Selective Parsers

    @Test("Config with only JSON skips form parsing")
    func test_bodyParser_jsonOnly_skipsForm() async throws {
        let config = BodyParserConfig(parsers: [.json])
        let conn = try await bodyParser(config)(makeConn(
            method: .post,
            contentType: "application/x-www-form-urlencoded",
            body: Data("key=val".utf8)
        ))
        #expect(conn.bodyParams.isEmpty)
    }

    // MARK: - Typed Assign Keys

    @Test("Typed keys work with bodyParser results")
    func test_bodyParser_typedKeys() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/x-www-form-urlencoded",
            body: Data("name=typed".utf8)
        ))
        #expect(conn[BodyParamsKey.self]?["name"] == "typed")
    }

    // MARK: - PUT and PATCH

    @Test("PUT bodies are parsed")
    func test_bodyParser_putMethod_parses() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .put,
            contentType: "application/json",
            body: Data(#"{"updated":true}"#.utf8)
        ))
        #expect(conn.parsedJSON != nil)
    }

    @Test("PATCH bodies are parsed")
    func test_bodyParser_patchMethod_parses() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .patch,
            contentType: "application/json",
            body: Data(#"{"patched":true}"#.utf8)
        ))
        #expect(conn.parsedJSON != nil)
    }

    // MARK: - Does Not Halt

    @Test("Body parser does not halt on success")
    func test_bodyParser_doesNotHalt() async throws {
        let conn = try await bodyParser()(makeConn(
            method: .post,
            contentType: "application/json",
            body: Data(#"{"ok":true}"#.utf8)
        ))
        #expect(!conn.isHalted)
    }
}

// MARK: - Helpers

private func makeConn(
    method: HTTPRequest.Method = .post,
    contentType: String,
    body: Data
) -> Connection {
    var request = HTTPRequest(method: method, scheme: "https", authority: "example.com", path: "/")
    request.headerFields[.contentType] = contentType
    return Connection(request: request, requestBody: .buffered(body))
}

private func buildMultipartBody(boundary: String, parts: [(String, Data?)]) -> Data {
    var result = Data()
    let crlf = Data("\r\n".utf8)
    for (headers, _) in parts {
        result.append(Data("--\(boundary)\r\n".utf8))
        result.append(Data(headers.utf8))
        result.append(crlf)
    }
    result.append(Data("--\(boundary)--\r\n".utf8))
    return result
}
