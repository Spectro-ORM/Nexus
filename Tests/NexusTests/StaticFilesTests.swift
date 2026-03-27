import Foundation
import HTTPTypes
import Testing

@testable import Nexus

@Suite("StaticFiles")
struct StaticFilesTests {

    /// Creates a temporary directory with test files and returns the path.
    private func makeTempDir() throws -> String {
        let tmp = NSTemporaryDirectory() + "nexus-static-tests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: tmp,
            withIntermediateDirectories: true
        )
        // Create test files
        try Data("body { color: red; }".utf8).write(
            to: URL(fileURLWithPath: tmp + "/style.css")
        )
        try Data("console.log('hi')".utf8).write(
            to: URL(fileURLWithPath: tmp + "/app.js")
        )
        try Data("<html></html>".utf8).write(
            to: URL(fileURLWithPath: tmp + "/index.html")
        )
        // Create a subdirectory with a file
        let subdir = tmp + "/images"
        try FileManager.default.createDirectory(
            atPath: subdir,
            withIntermediateDirectories: true
        )
        try Data("PNG".utf8).write(
            to: URL(fileURLWithPath: subdir + "/logo.png")
        )
        return tmp
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    private func buildConn(
        method: HTTPRequest.Method = .get,
        path: String
    ) -> Connection {
        let request = HTTPRequest(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path
        )
        return Connection(request: request)
    }

    @Test func test_staticFiles_GET_servesExistingFile() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(path: "/static/style.css")
        let result = try await plug(conn)

        #expect(result.response.status == .ok)
        #expect(result.isHalted == true)
        #expect(result.response.headerFields[.contentType] == "text/css")
    }

    @Test func test_staticFiles_GET_servesNestedFile() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(path: "/static/images/logo.png")
        let result = try await plug(conn)

        #expect(result.response.status == .ok)
        #expect(result.isHalted == true)
        #expect(result.response.headerFields[.contentType] == "image/png")
    }

    @Test func test_staticFiles_GET_nonMatchingPrefix_passesThrough() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(path: "/api/users")
        let result = try await plug(conn)

        #expect(result.response.status == .ok)
        #expect(result.isHalted == false)
    }

    @Test func test_staticFiles_GET_pathTraversal_returns403() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(path: "/static/../../../etc/passwd")
        let result = try await plug(conn)

        #expect(result.response.status == .forbidden)
        #expect(result.isHalted == true)
    }

    @Test func test_staticFiles_GET_nullByte_doesNotServeFile() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        // Null bytes in paths are either rejected or cause the file to not be found
        let conn = buildConn(path: "/static/style.css\0.html")
        let result = try await plug(conn)

        // The file "style.css\0.html" does not exist, so it should not be served
        #expect(result.response.status != .ok)
    }

    @Test func test_staticFiles_GET_fileNotFound_returns404WithoutHalting() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(path: "/static/nonexistent.css")
        let result = try await plug(conn)

        #expect(result.response.status == .notFound)
        #expect(result.isHalted == false)
    }

    @Test func test_staticFiles_POST_passesThrough() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(method: .post, path: "/static/style.css")
        let result = try await plug(conn)

        // POST should pass through unchanged
        #expect(result.isHalted == false)
    }

    @Test func test_staticFiles_HEAD_servesHeadersWithEmptyBody() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(method: .head, path: "/static/style.css")
        let result = try await plug(conn)

        #expect(result.response.status == .ok)
        #expect(result.isHalted == true)
        #expect(result.response.headerFields[.contentType] == "text/css")
        if case .empty = result.responseBody {
            // Expected — HEAD has no body
        } else {
            Issue.record("HEAD response should have empty body")
        }
    }

    @Test func test_staticFiles_only_allowsListedExtensions() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(
            StaticFilesConfig(at: "/static", from: dir, only: ["css"])
        )

        // .css should be served
        let cssConn = buildConn(path: "/static/style.css")
        let cssResult = try await plug(cssConn)
        #expect(cssResult.response.status == .ok)
        #expect(cssResult.isHalted == true)

        // .js should pass through
        let jsConn = buildConn(path: "/static/app.js")
        let jsResult = try await plug(jsConn)
        #expect(jsResult.isHalted == false)
    }

    @Test func test_staticFiles_except_blocksListedExtensions() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(
            StaticFilesConfig(at: "/static", from: dir, except: ["js"])
        )

        // .css should be served
        let cssConn = buildConn(path: "/static/style.css")
        let cssResult = try await plug(cssConn)
        #expect(cssResult.response.status == .ok)

        // .js should pass through
        let jsConn = buildConn(path: "/static/app.js")
        let jsResult = try await plug(jsConn)
        #expect(jsResult.isHalted == false)
    }

    @Test func test_staticFiles_prefixOnly_passesThrough() async throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }

        let plug = staticFiles(StaticFilesConfig(at: "/static", from: dir))
        let conn = buildConn(path: "/static")
        let result = try await plug(conn)

        // Requesting the prefix itself with no file should pass through
        #expect(result.isHalted == false)
    }
}
