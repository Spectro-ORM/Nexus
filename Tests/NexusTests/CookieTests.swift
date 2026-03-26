import Testing
import Foundation
import HTTPTypes
@testable import Nexus

// MARK: - Request Cookie Parsing

@Suite("Request Cookies")
struct RequestCookieTests {

    private func makeConnection(cookieHeader: String? = nil) -> Connection {
        var request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/"
        )
        if let cookieHeader {
            request.headerFields[.cookie] = cookieHeader
        }
        return Connection(request: request)
    }

    @Test("test_reqCookies_emptyWhenNoCookieHeader")
    func test_reqCookies_emptyWhenNoCookieHeader() {
        let conn = makeConnection()
        #expect(conn.reqCookies.isEmpty)
    }

    @Test("test_reqCookies_parsesSingleCookie")
    func test_reqCookies_parsesSingleCookie() {
        let conn = makeConnection(cookieHeader: "session=abc123")
        #expect(conn.reqCookies["session"] == "abc123")
    }

    @Test("test_reqCookies_parsesMultipleCookies")
    func test_reqCookies_parsesMultipleCookies() {
        let conn = makeConnection(cookieHeader: "a=1; b=2; c=3")
        #expect(conn.reqCookies["a"] == "1")
        #expect(conn.reqCookies["b"] == "2")
        #expect(conn.reqCookies["c"] == "3")
    }

    @Test("test_reqCookies_firstValueWinsForDuplicates")
    func test_reqCookies_firstValueWinsForDuplicates() {
        let conn = makeConnection(cookieHeader: "a=1; a=2")
        #expect(conn.reqCookies["a"] == "1")
    }

    @Test("test_reqCookies_handlesValueWithEquals")
    func test_reqCookies_handlesValueWithEquals() {
        let conn = makeConnection(cookieHeader: "token=abc=def==")
        #expect(conn.reqCookies["token"] == "abc=def==")
    }

    @Test("test_reqCookies_trimsWhitespace")
    func test_reqCookies_trimsWhitespace() {
        let conn = makeConnection(cookieHeader: "a=1;  b=2;   c=3")
        #expect(conn.reqCookies["a"] == "1")
        #expect(conn.reqCookies["b"] == "2")
        #expect(conn.reqCookies["c"] == "3")
    }
}

// MARK: - Cookie Header Value Serialization

@Suite("Cookie Header Value")
struct CookieHeaderValueTests {

    @Test("test_cookie_headerValue_minimalCookie")
    func test_cookie_headerValue_minimalCookie() {
        let cookie = Cookie(name: "id", value: "42")
        #expect(cookie.headerValue == "id=42")
    }

    @Test("test_cookie_headerValue_fullAttributes")
    func test_cookie_headerValue_fullAttributes() {
        let cookie = Cookie(
            name: "session",
            value: "abc",
            path: "/",
            domain: "example.com",
            maxAge: 3600,
            expires: "Thu, 01 Jan 2099 00:00:00 GMT",
            secure: true,
            httpOnly: true,
            sameSite: .lax
        )
        let header = cookie.headerValue
        #expect(header.contains("session=abc"))
        #expect(header.contains("Path=/"))
        #expect(header.contains("Domain=example.com"))
        #expect(header.contains("Max-Age=3600"))
        #expect(header.contains("Expires=Thu, 01 Jan 2099 00:00:00 GMT"))
        #expect(header.contains("Secure"))
        #expect(header.contains("HttpOnly"))
        #expect(header.contains("SameSite=Lax"))
    }

    @Test("test_cookie_headerValue_sameSiteStrict")
    func test_cookie_headerValue_sameSiteStrict() {
        let cookie = Cookie(name: "a", value: "b", sameSite: .strict)
        #expect(cookie.headerValue.contains("SameSite=Strict"))
    }

    @Test("test_cookie_headerValue_sameSiteNone")
    func test_cookie_headerValue_sameSiteNone() {
        let cookie = Cookie(name: "a", value: "b", secure: true, sameSite: Cookie.SameSite.none)
        #expect(cookie.headerValue.contains("SameSite=None"))
        #expect(cookie.headerValue.contains("Secure"))
    }
}

// MARK: - Response Cookie Helpers

@Suite("Response Cookies")
struct ResponseCookieTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/"
        )
        return Connection(request: request)
    }

    @Test("test_putRespCookie_appendsSetCookieHeader")
    func test_putRespCookie_appendsSetCookieHeader() {
        let conn = makeConnection()
            .putRespCookie(Cookie(name: "id", value: "42"))
        let values = conn.response.headerFields[values: .setCookie]
        #expect(values.count == 1)
        #expect(values[0] == "id=42")
    }

    @Test("test_putRespCookie_multipleCookies_multipleHeaders")
    func test_putRespCookie_multipleCookies_multipleHeaders() {
        let conn = makeConnection()
            .putRespCookie(Cookie(name: "a", value: "1"))
            .putRespCookie(Cookie(name: "b", value: "2"))
        let values = conn.response.headerFields[values: .setCookie]
        #expect(values.count == 2)
        #expect(values[0] == "a=1")
        #expect(values[1] == "b=2")
    }

    @Test("test_deleteRespCookie_setsMaxAgeZero")
    func test_deleteRespCookie_setsMaxAgeZero() {
        let conn = makeConnection()
            .deleteRespCookie("session")
        let values = conn.response.headerFields[values: .setCookie]
        #expect(values.count == 1)
        #expect(values[0].contains("session="))
        #expect(values[0].contains("Max-Age=0"))
        #expect(values[0].contains("Path=/"))
    }

    @Test("test_deleteRespCookie_withDomain")
    func test_deleteRespCookie_withDomain() {
        let conn = makeConnection()
            .deleteRespCookie("session", path: "/app", domain: "example.com")
        let values = conn.response.headerFields[values: .setCookie]
        #expect(values.count == 1)
        #expect(values[0].contains("Domain=example.com"))
        #expect(values[0].contains("Path=/app"))
    }
}
