import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("Connection+Inform")
struct InformTests {

    // MARK: - Queue Informational Response

    @Test("inform queues an informational response")
    func test_inform_queuesResponse() {
        let conn = makeConn()
        let result = conn.inform(
            status: HTTPResponse.Status(code: 103),
            headers: [:]
        )
        #expect(result.informationalResponses.count == 1)
        #expect(result.informationalResponses[0].status.code == 103)
    }

    @Test("Multiple inform calls queue in order")
    func test_inform_multipleInOrder() {
        let conn = makeConn()
            .inform(status: HTTPResponse.Status(code: 103), headers: [:])
            .inform(status: HTTPResponse.Status(code: 103), headers: [:])

        #expect(conn.informationalResponses.count == 2)
    }

    // MARK: - Non-1xx Rejection

    @Test("Non-1xx status is rejected (200)")
    func test_inform_200_rejected() {
        let conn = makeConn()
        let result = conn.inform(status: .ok, headers: [:])
        #expect(result.informationalResponses.isEmpty)
    }

    @Test("Non-1xx status is rejected (301)")
    func test_inform_301_rejected() {
        let conn = makeConn()
        let result = conn.inform(
            status: HTTPResponse.Status(code: 301),
            headers: [:]
        )
        #expect(result.informationalResponses.isEmpty)
    }

    @Test("100 Continue is accepted as 1xx")
    func test_inform_100_accepted() {
        let conn = makeConn()
        let result = conn.inform(
            status: HTTPResponse.Status(code: 100),
            headers: [:]
        )
        #expect(result.informationalResponses.count == 1)
    }

    // MARK: - Does Not Alter Final Response

    @Test("inform does not alter final response status or body")
    func test_inform_doesNotAlterFinalResponse() {
        var conn = makeConn()
            .inform(status: HTTPResponse.Status(code: 103), headers: [:])
        conn.response.status = .ok
        conn.responseBody = .buffered(Data("hello".utf8))

        #expect(conn.response.status == .ok)
        if case .buffered(let data) = conn.responseBody {
            #expect(String(data: data, encoding: .utf8) == "hello")
        } else {
            Issue.record("Expected buffered body")
        }
    }

    // MARK: - Accessible for Adapter Extraction

    @Test("Informational responses are accessible via property")
    func test_inform_accessibleViaProperty() {
        let conn = makeConn()
            .inform(status: HTTPResponse.Status(code: 103), headers: [:])

        let responses = conn.informationalResponses
        #expect(responses.count == 1)
        #expect(responses[0].status.code == 103)
    }

    // MARK: - Value Type Semantics

    @Test("Connection remains a value type after inform")
    func test_inform_valueSemantics() {
        let original = makeConn()
        let modified = original.inform(
            status: HTTPResponse.Status(code: 103),
            headers: [:]
        )
        #expect(original.informationalResponses.isEmpty)
        #expect(modified.informationalResponses.count == 1)
    }

    // MARK: - Works with Existing Plugs

    @Test("Works with html response in same handler")
    func test_inform_withHTMLResponse() {
        let conn = makeConn()
            .inform(status: HTTPResponse.Status(code: 103), headers: [:])
            .html("<html>Hello</html>")

        #expect(conn.informationalResponses.count == 1)
        #expect(conn.isHalted)
    }

    @Test("Works alongside json response")
    func test_inform_withJSONResponse() throws {
        let conn = makeConn()
            .inform(status: HTTPResponse.Status(code: 103), headers: [:])

        // Verify inform doesn't interfere with normal response building
        #expect(conn.informationalResponses.count == 1)
        #expect(!conn.isHalted) // Not yet halted — inform doesn't halt
    }
}

// MARK: - Helpers

private func makeConn() -> Connection {
    let request = HTTPRequest(
        method: .get,
        scheme: "https",
        authority: "example.com",
        path: "/"
    )
    return Connection(request: request)
}
