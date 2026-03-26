import Testing
import Foundation
import HTTPTypes
@testable import Nexus

// MARK: - RequestId Tests

@Suite("RequestId Plug")
struct RequestIdTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request)
    }

    @Test("test_requestId_setsAssign")
    func test_requestId_setsAssign() async throws {
        let plug = requestId()
        let result = try await plug(makeConnection())
        let id = result.assigns["request_id"] as? String
        #expect(id != nil)
        #expect(id?.isEmpty == false)
    }

    @Test("test_requestId_setsResponseHeader")
    func test_requestId_setsResponseHeader() async throws {
        let plug = requestId()
        let result = try await plug(makeConnection())
        let header = result.response.headerFields[HTTPField.Name("X-Request-Id")!]
        #expect(header != nil)
    }

    @Test("test_requestId_headerMatchesAssign")
    func test_requestId_headerMatchesAssign() async throws {
        let plug = requestId()
        let result = try await plug(makeConnection())
        let assignId = result.assigns["request_id"] as? String
        let headerId = result.response.headerFields[HTTPField.Name("X-Request-Id")!]
        #expect(assignId == headerId)
    }

    @Test("test_requestId_customGenerator")
    func test_requestId_customGenerator() async throws {
        let plug = requestId(generator: { "fixed-id-123" })
        let result = try await plug(makeConnection())
        #expect(result.assigns["request_id"] as? String == "fixed-id-123")
    }
}

// MARK: - RequestLogger Tests

@Suite("RequestLogger Plug")
struct RequestLoggerTests {

    private func makeConnection(method: HTTPRequest.Method = .get, path: String = "/") -> Connection {
        let request = HTTPRequest(method: method, scheme: "https", authority: "example.com", path: path)
        return Connection(request: request)
    }

    @Test("test_requestLogger_registersBeforeSendCallback")
    func test_requestLogger_registersBeforeSendCallback() async throws {
        let plug = requestLogger()
        let result = try await plug(makeConnection())
        #expect(result.beforeSend.count == 1)
    }

    @Test("test_requestLogger_logsOnBeforeSend")
    func test_requestLogger_logsOnBeforeSend() async throws {
        let tracker = LogTracker()
        let plug = requestLogger { line in
            tracker.log(line)
        }
        let conn = try await plug(makeConnection(method: .get, path: "/users"))
        // Simulate adapter calling runBeforeSend
        var final = conn
        final.response.status = .ok
        _ = final.runBeforeSend()
        let lines = tracker.lines
        #expect(lines.count == 1)
        #expect(lines[0].contains("GET"))
        #expect(lines[0].contains("/users"))
    }
}

// @unchecked Sendable: only used in single-threaded test context
private final class LogTracker: @unchecked Sendable {
    private(set) var lines: [String] = []
    func log(_ line: String) { lines.append(line) }
}

// MARK: - CORS Tests

@Suite("CORS Plug")
struct CORSTests {

    private func makeConnection(method: HTTPRequest.Method = .get) -> Connection {
        let request = HTTPRequest(method: method, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request)
    }

    @Test("test_cors_setsAllowOriginHeader")
    func test_cors_setsAllowOriginHeader() async throws {
        let plug = corsPlug(CORSConfig(allowedOrigin: "https://example.com"))
        let result = try await plug(makeConnection())
        let header = result.response.headerFields[HTTPField.Name("Access-Control-Allow-Origin")!]
        #expect(header == "https://example.com")
    }

    @Test("test_cors_setsAllowMethodsHeader")
    func test_cors_setsAllowMethodsHeader() async throws {
        let plug = corsPlug(CORSConfig(allowedMethods: ["GET", "POST"]))
        let result = try await plug(makeConnection())
        let header = result.response.headerFields[HTTPField.Name("Access-Control-Allow-Methods")!]
        #expect(header == "GET, POST")
    }

    @Test("test_cors_optionsPreflight_haltsWithNoContent")
    func test_cors_optionsPreflight_haltsWithNoContent() async throws {
        let plug = corsPlug()
        let result = try await plug(makeConnection(method: .options))
        #expect(result.response.status == .noContent)
        #expect(result.isHalted == true)
    }

    @Test("test_cors_optionsPreflight_setsMaxAge")
    func test_cors_optionsPreflight_setsMaxAge() async throws {
        let plug = corsPlug(CORSConfig(maxAge: 3600))
        let result = try await plug(makeConnection(method: .options))
        let header = result.response.headerFields[HTTPField.Name("Access-Control-Max-Age")!]
        #expect(header == "3600")
    }

    @Test("test_cors_nonOptions_doesNotHalt")
    func test_cors_nonOptions_doesNotHalt() async throws {
        let plug = corsPlug()
        let result = try await plug(makeConnection(method: .get))
        #expect(result.isHalted == false)
    }

    @Test("test_cors_credentials_setsHeader")
    func test_cors_credentials_setsHeader() async throws {
        let plug = corsPlug(CORSConfig(allowCredentials: true))
        let result = try await plug(makeConnection())
        let header = result.response.headerFields[HTTPField.Name("Access-Control-Allow-Credentials")!]
        #expect(header == "true")
    }

    @Test("test_cors_defaultConfig_allowsAll")
    func test_cors_defaultConfig_allowsAll() async throws {
        let plug = corsPlug()
        let result = try await plug(makeConnection())
        let origin = result.response.headerFields[HTTPField.Name("Access-Control-Allow-Origin")!]
        #expect(origin == "*")
    }
}
