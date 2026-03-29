import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Head Plug")
struct HeadTests {

    let plug = head()

    // MARK: - HEAD → GET Conversion

    @Test("HEAD request is converted to GET")
    func test_head_convertedToGet() async throws {
        let conn = makeConn(method: .head, path: "/users")
        let result = try await plug(conn)
        #expect(result.request.method == .get)
    }

    @Test("HEAD response body is stripped after beforeSend")
    func test_head_bodyStripped_afterBeforeSend() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.response.status = .ok
            copy.response.headerFields[.contentType] = "text/html; charset=utf-8"
            copy.response.headerFields[.contentLength] = "42"
            copy.responseBody = .buffered(Data("<html>hello</html>".utf8))
            return copy
        }
        let app = pipeline([plug, handler])
        let conn = makeConn(method: .head, path: "/page")
        let result = try await app(conn)
        let final = result.runBeforeSend()

        if case .empty = final.responseBody {
            // expected
        } else {
            Issue.record("Expected empty body for HEAD response")
        }
    }

    @Test("HEAD preserves Content-Length header")
    func test_head_preservesContentLength() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.response.headerFields[.contentLength] = "1024"
            copy.responseBody = .buffered(Data(repeating: 0, count: 1024))
            return copy
        }
        let app = pipeline([plug, handler])
        let conn = makeConn(method: .head, path: "/")
        let final = try await app(conn).runBeforeSend()

        #expect(final.response.headerFields[.contentLength] == "1024")
    }

    @Test("HEAD preserves Content-Type header")
    func test_head_preservesContentType() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.response.headerFields[.contentType] = "application/json"
            copy.responseBody = .buffered(Data("{}".utf8))
            return copy
        }
        let app = pipeline([plug, handler])
        let conn = makeConn(method: .head, path: "/")
        let final = try await app(conn).runBeforeSend()

        #expect(final.response.headerFields[.contentType] == "application/json")
    }

    // MARK: - Pass-Through

    @Test("GET request passes through unchanged with body intact")
    func test_get_passesThrough_bodyIntact() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.responseBody = .buffered(Data("hello".utf8))
            return copy
        }
        let app = pipeline([plug, handler])
        let conn = makeConn(method: .get, path: "/")
        let final = try await app(conn).runBeforeSend()

        #expect(final.request.method == .get)
        if case .buffered(let data) = final.responseBody {
            #expect(String(data: data, encoding: .utf8) == "hello")
        } else {
            Issue.record("Expected buffered body for GET response")
        }
    }

    @Test("POST request passes through unchanged")
    func test_post_passesThrough() async throws {
        let conn = makeConn(method: .post, path: "/")
        let result = try await plug(conn)
        #expect(result.request.method == .post)
    }

    // MARK: - Pipeline Composition

    @Test("Works in a pipeline with other plugs")
    func test_pipeline_composition() async throws {
        let handler: Plug = { conn in
            var copy = conn
            copy.response.status = .ok
            copy.responseBody = .buffered(Data("body".utf8))
            return copy
        }
        let app = pipeline([plug, requestId(), handler])
        let conn = makeConn(method: .head, path: "/test")
        let result = try await app(conn)
        let final = result.runBeforeSend()

        #expect(final.assigns["request_id"] != nil)
        if case .empty = final.responseBody {
            // expected
        } else {
            Issue.record("Expected empty body for HEAD response in pipeline")
        }
    }

    @Test("HEAD to a route that halts returns correct status")
    func test_head_haltedRoute_returnsStatus() async throws {
        let handler: Plug = { conn in
            conn.respond(status: .notFound, body: .string("Not found"))
        }
        let app = pipeline([plug, handler])
        let conn = makeConn(method: .head, path: "/missing")
        let result = try await app(conn)
        let final = result.runBeforeSend()

        #expect(final.response.status == .notFound)
        if case .empty = final.responseBody {
            // expected — body stripped even for 404
        } else {
            Issue.record("Expected empty body for HEAD 404 response")
        }
    }
}

// MARK: - Helpers

private func makeConn(
    method: HTTPRequest.Method = .get,
    path: String = "/"
) -> Connection {
    let request = HTTPRequest(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path
    )
    return Connection(request: request)
}
