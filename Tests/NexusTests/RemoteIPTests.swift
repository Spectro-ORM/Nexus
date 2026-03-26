import Testing
import HTTPTypes
@testable import Nexus

@Suite("Remote IP")
struct RemoteIPTests {

    private func makeConnection() -> Connection {
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/"
        )
        return Connection(request: request)
    }

    @Test("test_remoteIP_nilWhenNotSet")
    func test_remoteIP_nilWhenNotSet() {
        let conn = makeConnection()
        #expect(conn.remoteIP == nil)
    }

    @Test("test_remoteIP_returnsValueFromAssigns")
    func test_remoteIP_returnsValueFromAssigns() {
        let conn = makeConnection()
            .assign(key: Connection.remoteIPKey, value: "192.168.1.1")
        #expect(conn.remoteIP == "192.168.1.1")
    }

    @Test("test_remoteIP_supportsIPv6")
    func test_remoteIP_supportsIPv6() {
        let conn = makeConnection()
            .assign(key: Connection.remoteIPKey, value: "::1")
        #expect(conn.remoteIP == "::1")
    }

    @Test("test_remoteIP_nilWhenAssignHasWrongType")
    func test_remoteIP_nilWhenAssignHasWrongType() {
        let conn = makeConnection()
            .assign(key: Connection.remoteIPKey, value: 12345)
        #expect(conn.remoteIP == nil)
    }
}
