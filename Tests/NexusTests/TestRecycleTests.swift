import Foundation
import Testing
import HTTPTypes
@testable import Nexus
import NexusTest

@Suite("TestConnection.recycle")
struct TestRecycleTests {

    // MARK: - Cookie Recycling

    @Test("Carries Set-Cookie response cookies as Cookie request header")
    func test_recycle_carriesCookies() {
        var conn = makeResponseConn()
        conn = appendSetCookie(conn, "session=abc123; Path=/; HttpOnly")

        let recycled = TestConnection.recycle(conn)
        #expect(recycled.reqCookies["session"] == "abc123")
    }

    @Test("Multiple Set-Cookie headers are all carried forward")
    func test_recycle_multipleCookies() {
        var conn = makeResponseConn()
        conn = appendSetCookie(conn, "session=abc; Path=/")
        conn = appendSetCookie(conn, "theme=dark; Path=/")

        let recycled = TestConnection.recycle(conn)
        #expect(recycled.reqCookies["session"] == "abc")
        #expect(recycled.reqCookies["theme"] == "dark")
    }

    @Test("Set-Cookie with Max-Age=0 is excluded (deleted cookie)")
    func test_recycle_maxAgeZero_excluded() {
        var conn = makeResponseConn()
        conn = appendSetCookie(conn, "keep=yes; Path=/")
        conn = appendSetCookie(conn, "delete=me; Max-Age=0; Path=/")

        let recycled = TestConnection.recycle(conn)
        #expect(recycled.reqCookies["keep"] == "yes")
        #expect(recycled.reqCookies["delete"] == nil)
    }

    // MARK: - Request Parameters

    @Test("Recycled connection has correct method, path, and body")
    func test_recycle_correctParameters() {
        let conn = makeResponseConn()
        let recycled = TestConnection.recycle(
            conn,
            method: .post,
            path: "/submit",
            body: .buffered(Data("data".utf8))
        )

        #expect(recycled.request.method == .post)
        #expect(recycled.request.path == "/submit")
        if case .buffered(let data) = recycled.requestBody {
            #expect(String(data: data, encoding: .utf8) == "data")
        } else {
            Issue.record("Expected buffered body")
        }
    }

    // MARK: - Cookie Merging

    @Test("Explicit Cookie header merges with recycled cookies")
    func test_recycle_explicitCookieMerge() {
        var conn = makeResponseConn()
        conn = appendSetCookie(conn, "recycled=yes; Path=/")

        let recycled = TestConnection.recycle(
            conn,
            headers: [.cookie: "explicit=true"]
        )

        #expect(recycled.reqCookies["recycled"] == "yes")
        #expect(recycled.reqCookies["explicit"] == "true")
    }

    @Test("Explicit Cookie overrides recycled cookie with same name")
    func test_recycle_explicitOverridesRecycled() {
        var conn = makeResponseConn()
        conn = appendSetCookie(conn, "token=old; Path=/")

        let recycled = TestConnection.recycle(
            conn,
            headers: [.cookie: "token=new"]
        )

        #expect(recycled.reqCookies["token"] == "new")
    }

    // MARK: - Defaults

    @Test("Default parameters match TestConnection.build defaults")
    func test_recycle_defaultParameters() {
        let conn = makeResponseConn()
        let recycled = TestConnection.recycle(conn)

        #expect(recycled.request.method == .get)
        #expect(recycled.request.path == "/")
        #expect(recycled.request.scheme == "https")
        #expect(recycled.request.authority == "example.com")
    }

    // MARK: - Isolation

    @Test("remoteIP is not carried forward")
    func test_recycle_remoteIPNotCarried() {
        var conn = makeResponseConn()
        conn = conn.assign(key: Connection.remoteIPKey, value: "1.2.3.4")

        let recycled = TestConnection.recycle(conn)
        #expect(recycled.remoteIP == nil)
    }

    @Test("assigns from previous connection are not carried forward")
    func test_recycle_assignsNotCarried() {
        var conn = makeResponseConn()
        conn = conn.assign(key: "user_id", value: "42")

        let recycled = TestConnection.recycle(conn)
        #expect(recycled.assigns["user_id"] == nil)
    }
}

// MARK: - Helpers

private func makeResponseConn() -> Connection {
    let request = HTTPRequest(
        method: .get,
        scheme: "https",
        authority: "example.com",
        path: "/"
    )
    var conn = Connection(request: request)
    conn.response.status = .ok
    return conn
}

private func appendSetCookie(_ conn: Connection, _ value: String) -> Connection {
    var copy = conn
    copy.response.headerFields.append(
        HTTPField(name: .setCookie, value: value)
    )
    return copy
}
