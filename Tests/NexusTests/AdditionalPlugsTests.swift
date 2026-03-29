import Testing
import Foundation
import HTTPTypes
@testable import Nexus
import NexusTest

// @unchecked Sendable: only used in single-threaded test context
private final class LockedFlag: @unchecked Sendable {
    private(set) var value = false
    func set() { value = true }
}

// MARK: - ContentNegotiation Tests

@Suite("ContentNegotiation")
struct ContentNegotiationTests {

    @Test("returns 406 when Accept has no match")
    func test_contentNeg_noMatch_returns406() async throws {
        let plug = ContentNegotiation(supported: ["application/json"])
        var headers = HTTPFields()
        headers[.accept] = "text/plain"
        let conn = TestConnection.build(path: "/", headers: headers)
        let result = try await plug.call(conn)
        #expect(result.response.status == .notAcceptable)
        #expect(result.isHalted)
    }

    @Test("exact match stores negotiated type in assigns")
    func test_contentNeg_exactMatch_storesType() async throws {
        let plug = ContentNegotiation(supported: ["application/json", "text/html"])
        var headers = HTTPFields()
        headers[.accept] = "application/json"
        let conn = TestConnection.build(path: "/", headers: headers)
        let result = try await plug.call(conn)
        #expect(result[ContentNegotiation.NegotiatedTypeKey.self] == "application/json")
        #expect(!result.isHalted)
    }

    @Test("wildcard subtype match selects first supported type")
    func test_contentNeg_wildcardSubtype_matches() async throws {
        let plug = ContentNegotiation(supported: ["application/json"])
        var headers = HTTPFields()
        headers[.accept] = "application/*"
        let conn = TestConnection.build(path: "/", headers: headers)
        let result = try await plug.call(conn)
        #expect(result[ContentNegotiation.NegotiatedTypeKey.self] == "application/json")
    }

    @Test("*/* matches first supported type")
    func test_contentNeg_starStar_matchesFirst() async throws {
        let plug = ContentNegotiation(supported: ["text/html", "application/json"])
        var headers = HTTPFields()
        headers[.accept] = "*/*"
        let conn = TestConnection.build(path: "/", headers: headers)
        let result = try await plug.call(conn)
        #expect(result[ContentNegotiation.NegotiatedTypeKey.self] == "text/html")
    }

    @Test("no Accept header uses default type")
    func test_contentNeg_noAcceptHeader_usesDefault() async throws {
        let plug = ContentNegotiation(supported: ["application/json"], defaultType: "text/html")
        let conn = TestConnection.build(path: "/")
        let result = try await plug.call(conn)
        #expect(result[ContentNegotiation.NegotiatedTypeKey.self] == "text/html")
    }

    @Test("no Accept header uses first supported when no default")
    func test_contentNeg_noAcceptHeader_noDefault_usesFirst() async throws {
        let plug = ContentNegotiation(supported: ["application/json"])
        let conn = TestConnection.build(path: "/")
        let result = try await plug.call(conn)
        #expect(result[ContentNegotiation.NegotiatedTypeKey.self] == "application/json")
    }

    @Test("quality values respected: higher q wins")
    func test_contentNeg_qValues_highestQWins() async throws {
        let plug = ContentNegotiation(supported: ["text/html", "application/json"])
        var headers = HTTPFields()
        headers[.accept] = "text/html;q=0.9, application/json;q=1.0"
        let conn = TestConnection.build(path: "/", headers: headers)
        let result = try await plug.call(conn)
        // application/json has higher q
        #expect(result[ContentNegotiation.NegotiatedTypeKey.self] == "application/json")
    }

    @Test("zero q value means not acceptable")
    func test_contentNeg_zeroQ_notAcceptable() async throws {
        let plug = ContentNegotiation(supported: ["text/html"])
        var headers = HTTPFields()
        headers[.accept] = "text/html;q=0"
        let conn = TestConnection.build(path: "/", headers: headers)
        let result = try await plug.call(conn)
        #expect(result.response.status == .notAcceptable)
    }

    @Test("works inside pipeline")
    func test_contentNeg_insidePipeline_passesThrough() async throws {
        let plug = ContentNegotiation(supported: ["application/json"])
        var headers = HTTPFields()
        headers[.accept] = "application/json"
        let conn = TestConnection.build(path: "/", headers: headers)
        let handlerCalled = LockedFlag()
        let handler: Plug = { c in
            handlerCalled.set()
            return c
        }
        let app = pipeline([plug.asPlug(), handler])
        _ = try await app(conn)
        #expect(handlerCalled.value)
    }
}

// MARK: - Timeout Tests

@Suite("Timeout")
struct TimeoutTests {

    @Test("plug completes before timeout returns result")
    func test_timeout_fastPlug_returnsResult() async throws {
        let timeout = Timeout(seconds: 5)
        let plug: Plug = { conn in conn.assign(key: "done", value: true) }
        let wrapped = timeout.wrap(plug)
        let conn = TestConnection.build(path: "/")
        let result = try await wrapped(conn)
        #expect(result.assigns["done"] as? Bool == true)
    }

    @Test("plug exceeding timeout throws TimeoutError")
    func test_timeout_slowPlug_throwsTimeoutError() async throws {
        let timeout = Timeout(nanoseconds: 10_000_000)  // 10 ms
        let slowPlug: Plug = { conn in
            try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 s
            return conn
        }
        let wrapped = timeout.wrap(slowPlug)
        let conn = TestConnection.build(path: "/")
        await #expect(throws: Timeout.TimeoutError.self) {
            _ = try await wrapped(conn)
        }
    }

    @Test("timeout works with onError for friendly response")
    func test_timeout_withOnError_returns503() async throws {
        let timeout = Timeout(nanoseconds: 10_000_000)  // 10 ms
        let slowPlug: Plug = { conn in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return conn
        }
        let app = onError(timeout.wrap(slowPlug)) { conn, error in
            if error is Timeout.TimeoutError {
                return conn.respond(status: .serviceUnavailable, body: .string("Timed out"))
            }
            return conn.respond(status: .internalServerError)
        }
        let conn = TestConnection.build(path: "/")
        let result = try await app(conn)
        #expect(result.response.status == .serviceUnavailable)
    }
}

// MARK: - Compression Tests

@Suite("Compression")
struct CompressionTests {

    private func largeBody(_ size: Int = 2048) -> Data {
        Data(String(repeating: "Hello, World! ", count: size / 14).utf8)
    }

    @Test("small body below minimumLength is not compressed")
    func test_compression_smallBody_notCompressed() async throws {
        let plug = Compression(minimumLength: 1024)
        let conn = TestConnection.build(path: "/")
        var result = try await plug.call(conn)
        result.responseBody = .buffered(Data("short".utf8))
        let final = result.runBeforeSend()
        // No Content-Encoding should be set
        if let encoding = HTTPField.Name("Content-Encoding") {
            #expect(final.response.headerFields[encoding] == nil)
        }
    }

    @Test("deflate compression applied when client accepts deflate")
    func test_compression_deflate_compressesBody() async throws {
        let plug = Compression(algorithms: [.deflate], minimumLength: 100)
        var headers = HTTPFields()
        headers[.acceptEncoding] = "deflate"
        let conn = TestConnection.build(path: "/", headers: headers)
        var result = try await plug.call(conn)
        let original = largeBody()
        result.responseBody = .buffered(original)
        let final = result.runBeforeSend()

        if let encodingField = HTTPField.Name("Content-Encoding") {
            #expect(final.response.headerFields[encodingField] == "deflate")
        }
        if case .buffered(let data) = final.responseBody {
            #expect(data.count < original.count)
        }
    }

    @Test("gzip compression applied when client accepts gzip")
    func test_compression_gzip_compressesBody() async throws {
        let plug = Compression(algorithms: [.gzip], minimumLength: 100)
        var headers = HTTPFields()
        headers[.acceptEncoding] = "gzip"
        let conn = TestConnection.build(path: "/", headers: headers)
        var result = try await plug.call(conn)
        let original = largeBody()
        result.responseBody = .buffered(original)
        let final = result.runBeforeSend()

        if let encodingField = HTTPField.Name("Content-Encoding") {
            #expect(final.response.headerFields[encodingField] == "gzip")
        }
        if case .buffered(let data) = final.responseBody {
            // Gzip output should start with magic bytes 1F 8B
            #expect(data.count >= 2)
            #expect(data[0] == 0x1F && data[1] == 0x8B)
        }
    }

    @Test("no compression when Accept-Encoding absent")
    func test_compression_noAcceptEncoding_bodyUnchanged() async throws {
        let plug = Compression(minimumLength: 100)
        let conn = TestConnection.build(path: "/")
        var result = try await plug.call(conn)
        let original = largeBody()
        result.responseBody = .buffered(original)
        let final = result.runBeforeSend()

        if let encodingField = HTTPField.Name("Content-Encoding") {
            #expect(final.response.headerFields[encodingField] == nil)
        }
        if case .buffered(let data) = final.responseBody {
            #expect(data == original)
        }
    }

    @Test("compression not applied to streaming bodies")
    func test_compression_streamBody_skipped() async throws {
        let plug = Compression(minimumLength: 1)
        var headers = HTTPFields()
        headers[.acceptEncoding] = "gzip"
        let conn = TestConnection.build(path: "/", headers: headers)
        var result = try await plug.call(conn)
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            continuation.finish()
        }
        result.responseBody = .stream(stream)
        let final = result.runBeforeSend()

        if let encodingField = HTTPField.Name("Content-Encoding") {
            #expect(final.response.headerFields[encodingField] == nil)
        }
    }
}

// MARK: - Favicon Tests

@Suite("Favicon")
struct FaviconTests {

    private let iconData = Data([0x00, 0x00, 0x01, 0x00, 0xFF, 0xFE])  // minimal fake ICO

    @Test("serves favicon for exact path")
    func test_favicon_exactPath_servesIcon() async throws {
        let plug = Favicon(iconData: iconData, iconPath: "/favicon.ico")
        let conn = TestConnection.build(path: "/favicon.ico")
        let result = try await plug.call(conn)
        #expect(result.response.status == .ok)
        #expect(result.isHalted)
        if case .buffered(let data) = result.responseBody {
            #expect(data == iconData)
        } else {
            Issue.record("Expected buffered body")
        }
    }

    @Test("serves favicon with correct content-type for .ico")
    func test_favicon_icoPath_setsIconMimeType() async throws {
        let plug = Favicon(iconData: iconData, iconPath: "/favicon.ico")
        let conn = TestConnection.build(path: "/favicon.ico")
        let result = try await plug.call(conn)
        #expect(result.response.headerFields[.contentType] == "image/x-icon")
    }

    @Test("favicon serves PNG with correct content-type")
    func test_favicon_pngPath_setsPngMimeType() async throws {
        let plug = Favicon(iconData: iconData, iconPath: "/favicon.png")
        let conn = TestConnection.build(path: "/favicon.png")
        let result = try await plug.call(conn)
        #expect(result.response.headerFields[.contentType] == "image/png")
    }

    @Test("non-favicon path passes through")
    func test_favicon_otherPath_passesThrough() async throws {
        let plug = Favicon(iconData: iconData, iconPath: "/favicon.ico")
        let conn = TestConnection.build(path: "/index.html")
        let result = try await plug.call(conn)
        #expect(!result.isHalted)
    }

    @Test("favicon path with query string is served")
    func test_favicon_pathWithQuery_servesIcon() async throws {
        let plug = Favicon(iconData: iconData, iconPath: "/favicon.ico")
        let conn = TestConnection.build(path: "/favicon.ico?v=2")
        let result = try await plug.call(conn)
        #expect(result.response.status == .ok)
        #expect(result.isHalted)
    }

    @Test("favicon works inside pipeline")
    func test_favicon_insidePipeline_haltsPreventsHandler() async throws {
        let plug = Favicon(iconData: iconData)
        let handlerCalled = LockedFlag()
        let handler: Plug = { conn in
            handlerCalled.set()
            return conn
        }
        let app = pipeline([plug.asPlug(), handler])
        let conn = TestConnection.build(path: "/favicon.ico")
        let result = try await app(conn)
        #expect(result.isHalted)
        #expect(!handlerCalled.value)
    }

    @Test("custom icon path is intercepted")
    func test_favicon_customPath_intercepted() async throws {
        let plug = Favicon(iconData: iconData, iconPath: "/static/icon.ico")
        let conn = TestConnection.build(path: "/static/icon.ico")
        let result = try await plug.call(conn)
        #expect(result.isHalted)
        #expect(result.response.status == .ok)
    }
}
