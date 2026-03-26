import Testing
import Foundation
import HTTPTypes
@testable import Nexus

@Suite("Connection Convenience")
struct ConvenienceTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        return Connection(request: request)
    }

    // MARK: - Header Helpers

    @Test("test_connection_putRespHeader_setsHeader")
    func test_connection_putRespHeader_setsHeader() {
        let conn = makeConnection().putRespHeader(.server, "Nexus")
        #expect(conn.response.headerFields[.server] == "Nexus")
    }

    @Test("test_connection_deleteRespHeader_removesHeader")
    func test_connection_deleteRespHeader_removesHeader() {
        let conn = makeConnection()
            .putRespHeader(.server, "Nexus")
            .deleteRespHeader(.server)
        #expect(conn.response.headerFields[.server] == nil)
    }

    @Test("test_connection_getReqHeader_returnsValue")
    func test_connection_getReqHeader_returnsValue() {
        var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/")
        request.headerFields[.authorization] = "Bearer token123"
        let conn = Connection(request: request)
        #expect(conn.getReqHeader(.authorization) == "Bearer token123")
    }

    @Test("test_connection_getReqHeader_returnsNilWhenMissing")
    func test_connection_getReqHeader_returnsNilWhenMissing() {
        let conn = makeConnection()
        #expect(conn.getReqHeader(.authorization) == nil)
    }

    @Test("test_connection_putRespContentType_setsContentType")
    func test_connection_putRespContentType_setsContentType() {
        let conn = makeConnection().putRespContentType("text/html")
        #expect(conn.response.headerFields[.contentType] == "text/html")
    }

    // MARK: - putStatus

    @Test("test_connection_putStatus_setsStatusWithoutHalting")
    func test_connection_putStatus_setsStatusWithoutHalting() {
        let conn = makeConnection().putStatus(.notFound)
        #expect(conn.response.status == .notFound)
        #expect(conn.isHalted == false)
    }

    // MARK: - Request Metadata

    @Test("test_connection_host_returnsAuthority")
    func test_connection_host_returnsAuthority() {
        let conn = makeConnection()
        #expect(conn.host == "example.com")
    }

    @Test("test_connection_scheme_returnsScheme")
    func test_connection_scheme_returnsScheme() {
        let conn = makeConnection()
        #expect(conn.scheme == "https")
    }
}
