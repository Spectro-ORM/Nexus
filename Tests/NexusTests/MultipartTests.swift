import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Multipart Parsing")
struct MultipartTests {

    // MARK: - Single Text Field

    @Test("Parses a single text field")
    func test_multipart_singleTextField() throws {
        let conn = buildMultipart(
            boundary: "abc123",
            parts: [
                textPart(name: "name", value: "Alice"),
            ]
        )
        let params = try conn.multipartParams()
        #expect(params.field("name") == "Alice")
        #expect(params.files.isEmpty)
    }

    // MARK: - Single File Upload

    @Test("Parses a single file upload")
    func test_multipart_singleFileUpload() throws {
        let conn = buildMultipart(
            boundary: "abc123",
            parts: [
                filePart(name: "avatar", filename: "photo.jpg", contentType: "image/jpeg", data: Data([0xFF, 0xD8, 0xFF])),
            ]
        )
        let params = try conn.multipartParams()
        #expect(params.fields.isEmpty)
        let file = params.file("avatar")
        #expect(file?.filename == "photo.jpg")
        #expect(file?.contentType == "image/jpeg")
        #expect(file?.data == Data([0xFF, 0xD8, 0xFF]))
    }

    // MARK: - Mixed Fields and Files

    @Test("Parses mixed text fields and file uploads")
    func test_multipart_mixedFieldsAndFiles() throws {
        let conn = buildMultipart(
            boundary: "boundary42",
            parts: [
                textPart(name: "username", value: "bob"),
                textPart(name: "email", value: "bob@example.com"),
                filePart(name: "doc", filename: "report.pdf", contentType: "application/pdf", data: Data("pdf-content".utf8)),
            ]
        )
        let params = try conn.multipartParams()
        #expect(params.field("username") == "bob")
        #expect(params.field("email") == "bob@example.com")
        #expect(params.file("doc")?.filename == "report.pdf")
        #expect(params.file("doc")?.contentType == "application/pdf")
    }

    // MARK: - Multiple Files

    @Test("Last file wins for duplicate field names")
    func test_multipart_duplicateFieldNames_lastWins() throws {
        let conn = buildMultipart(
            boundary: "dup",
            parts: [
                filePart(name: "file", filename: "first.txt", contentType: "text/plain", data: Data("first".utf8)),
                filePart(name: "file", filename: "second.txt", contentType: "text/plain", data: Data("second".utf8)),
            ]
        )
        let params = try conn.multipartParams()
        #expect(params.file("file")?.filename == "second.txt")
        #expect(params.file("file")?.data == Data("second".utf8))
    }

    // MARK: - Boundary Extraction

    @Test("Extracts boundary from Content-Type")
    func test_boundary_extraction() {
        let ct = "multipart/form-data; boundary=abc123"
        #expect(MultipartParser.extractBoundary(from: ct) == "abc123")
    }

    @Test("Extracts quoted boundary")
    func test_boundary_extractionQuoted() {
        let ct = "multipart/form-data; boundary=\"abc 123\""
        #expect(MultipartParser.extractBoundary(from: ct) == "abc 123")
    }

    @Test("Returns nil for missing boundary")
    func test_boundary_missingReturnsNil() {
        let ct = "multipart/form-data"
        #expect(MultipartParser.extractBoundary(from: ct) == nil)
    }

    // MARK: - Error Cases

    @Test("Throws for empty body")
    func test_multipart_emptyBody_throws() {
        let conn = Connection(
            request: HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/"),
            requestBody: .empty
        )
        #expect(throws: NexusHTTPError.self) {
            _ = try conn.multipartParams()
        }
    }

    @Test("Throws for non-multipart Content-Type")
    func test_multipart_wrongContentType_throws() {
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        request.headerFields[.contentType] = "application/json"
        let conn = Connection(request: request, requestBody: .buffered(Data("{}".utf8)))
        #expect(throws: NexusHTTPError.self) {
            _ = try conn.multipartParams()
        }
    }

    @Test("Throws for missing boundary in Content-Type")
    func test_multipart_missingBoundary_throws() {
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        request.headerFields[.contentType] = "multipart/form-data"
        let conn = Connection(request: request, requestBody: .buffered(Data("body".utf8)))
        #expect(throws: NexusHTTPError.self) {
            _ = try conn.multipartParams()
        }
    }

    // MARK: - Special Characters

    @Test("Handles special characters in filename")
    func test_multipart_specialCharsInFilename() throws {
        let conn = buildMultipart(
            boundary: "special",
            parts: [
                filePart(name: "file", filename: "my file (1).txt", contentType: "text/plain", data: Data("content".utf8)),
            ]
        )
        let params = try conn.multipartParams()
        #expect(params.file("file")?.filename == "my file (1).txt")
    }

    // MARK: - File Without Content-Type

    @Test("File part without Content-Type header")
    func test_multipart_fileWithoutContentType() throws {
        let body = buildRawMultipart(
            boundary: "noct",
            rawParts: [
                "Content-Disposition: form-data; name=\"file\"; filename=\"data.bin\"\r\n\r\nBINARY",
            ]
        )
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        request.headerFields[.contentType] = "multipart/form-data; boundary=noct"
        let conn = Connection(request: request, requestBody: .buffered(body))
        let params = try conn.multipartParams()
        let file = params.file("file")
        #expect(file?.filename == "data.bin")
        #expect(file?.contentType == nil)
        #expect(file?.data == Data("BINARY".utf8))
    }

    // MARK: - LF Line Endings

    @Test("Handles LF-only line endings")
    func test_multipart_lfLineEndings() throws {
        let boundary = "lfonly"
        let raw = "--\(boundary)\nContent-Disposition: form-data; name=\"key\"\n\nvalue\n--\(boundary)--\n"
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
        request.headerFields[.contentType] = "multipart/form-data; boundary=\(boundary)"
        let conn = Connection(request: request, requestBody: .buffered(Data(raw.utf8)))
        let params = try conn.multipartParams()
        #expect(params.field("key") == "value")
    }
}

// MARK: - Test Helpers

private func buildMultipart(boundary: String, parts: [MultipartPart]) -> Connection {
    let body = buildRawMultipartData(boundary: boundary, parts: parts)
    var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
    request.headerFields[.contentType] = "multipart/form-data; boundary=\(boundary)"
    return Connection(request: request, requestBody: .buffered(body))
}

private func buildRawMultipart(boundary: String, rawParts: [String]) -> Data {
    var body = ""
    for part in rawParts {
        body += "--\(boundary)\r\n"
        body += part
        body += "\r\n"
    }
    body += "--\(boundary)--\r\n"
    return Data(body.utf8)
}

/// A test multipart part that supports both text and binary content.
private struct MultipartPart {
    let headers: String
    let body: Data
}

private func buildRawMultipartData(boundary: String, parts: [MultipartPart]) -> Data {
    var result = Data()
    let crlf = Data("\r\n".utf8)
    for part in parts {
        result.append(Data("--\(boundary)\r\n".utf8))
        result.append(Data(part.headers.utf8))
        result.append(Data("\r\n\r\n".utf8))
        result.append(part.body)
        result.append(crlf)
    }
    result.append(Data("--\(boundary)--\r\n".utf8))
    return result
}

private func textPart(name: String, value: String) -> MultipartPart {
    MultipartPart(
        headers: "Content-Disposition: form-data; name=\"\(name)\"",
        body: Data(value.utf8)
    )
}

private func filePart(name: String, filename: String, contentType: String, data: Data) -> MultipartPart {
    MultipartPart(
        headers: "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(contentType)",
        body: data
    )
}
