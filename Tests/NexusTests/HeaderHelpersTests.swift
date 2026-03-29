import Testing
import HTTPTypes
@testable import Nexus
import NexusTest

@Suite("Header Helpers")
struct HeaderHelpersTests {

    // MARK: - Response headers (typed)

    @Test("putRespHeader sets response header")
    func test_putRespHeader_typed_setsValue() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader(.xContentTypeOptions, "nosniff")
        #expect(conn.response.headerFields[.xContentTypeOptions] == "nosniff")
    }

    @Test("deleteRespHeader removes response header")
    func test_deleteRespHeader_typed_removesValue() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader(.xContentTypeOptions, "nosniff")
            .deleteRespHeader(.xContentTypeOptions)
        #expect(conn.response.headerFields[.xContentTypeOptions] == nil)
    }

    @Test("getRespHeader retrieves response header")
    func test_getRespHeader_typed_retrievesValue() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader(.contentType, "application/json")
        #expect(conn.getRespHeader(.contentType) == "application/json")
    }

    @Test("getRespHeader returns nil for absent header")
    func test_getRespHeader_typed_missingReturnsNil() {
        let conn = TestConnection.build(path: "/")
        #expect(conn.getRespHeader(.contentType) == nil)
    }

    // MARK: - Request headers (typed)

    @Test("putReqHeader sets request header")
    func test_putReqHeader_typed_setsValue() {
        let conn = TestConnection.build(path: "/")
            .putReqHeader(.authorization, "Bearer token")
        #expect(conn.request.headerFields[.authorization] == "Bearer token")
    }

    @Test("deleteReqHeader removes request header")
    func test_deleteReqHeader_typed_removesValue() {
        var headers = HTTPFields()
        headers[.authorization] = "Bearer token"
        let conn = TestConnection.build(path: "/", headers: headers)
            .deleteReqHeader(.authorization)
        #expect(conn.request.headerFields[.authorization] == nil)
    }

    @Test("deleteReqHeader on absent header is no-op")
    func test_deleteReqHeader_typed_absentIsNoOp() {
        let conn = TestConnection.build(path: "/")
        let result = conn.deleteReqHeader(.authorization)
        #expect(result.request.headerFields[.authorization] == nil)
    }

    @Test("getReqHeader retrieves request header")
    func test_getReqHeader_typed_retrievesValue() {
        var headers = HTTPFields()
        headers[.authorization] = "Bearer abc"
        let conn = TestConnection.build(path: "/", headers: headers)
        #expect(conn.getReqHeader(.authorization) == "Bearer abc")
    }

    // MARK: - String-based overloads

    @Test("putRespHeader string overload sets custom header")
    func test_putRespHeader_string_setsCustomHeader() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader("X-Request-ID", "abc-123")
        #expect(conn.getRespHeader("X-Request-ID") == "abc-123")
    }

    @Test("deleteRespHeader string overload removes header")
    func test_deleteRespHeader_string_removesHeader() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader("X-Custom", "value")
            .deleteRespHeader("X-Custom")
        #expect(conn.getRespHeader("X-Custom") == nil)
    }

    @Test("deleteRespHeader string overload on absent header is no-op")
    func test_deleteRespHeader_string_absentIsNoOp() {
        let conn = TestConnection.build(path: "/")
        let result = conn.deleteRespHeader("X-Missing")
        #expect(result.getRespHeader("X-Missing") == nil)
    }

    @Test("getRespHeader string overload retrieves value")
    func test_getRespHeader_string_retrievesValue() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader("X-Frame-Options", "DENY")
        #expect(conn.getRespHeader("X-Frame-Options") == "DENY")
    }

    @Test("getRespHeader string overload returns nil for absent header")
    func test_getRespHeader_string_absentReturnsNil() {
        let conn = TestConnection.build(path: "/")
        #expect(conn.getRespHeader("X-Missing") == nil)
    }

    @Test("putReqHeader string overload sets request header")
    func test_putReqHeader_string_setsHeader() {
        let conn = TestConnection.build(path: "/")
            .putReqHeader("X-Forwarded-For", "1.2.3.4")
        #expect(conn.getReqHeader("X-Forwarded-For") == "1.2.3.4")
    }

    @Test("deleteReqHeader string overload removes request header")
    func test_deleteReqHeader_string_removesHeader() {
        let conn = TestConnection.build(path: "/")
            .putReqHeader("X-Debug", "true")
            .deleteReqHeader("X-Debug")
        #expect(conn.getReqHeader("X-Debug") == nil)
    }

    @Test("getReqHeader string overload retrieves request header")
    func test_getReqHeader_string_retrievesValue() {
        let conn = TestConnection.build(path: "/")
            .putReqHeader("X-Api-Key", "secret")
        #expect(conn.getReqHeader("X-Api-Key") == "secret")
    }

    // MARK: - Chaining

    @Test("header helpers chain correctly")
    func test_headerHelpers_chain_allApplied() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader("X-Frame-Options", "DENY")
            .putRespHeader("X-Content-Type-Options", "nosniff")
            .putRespHeader("X-XSS-Protection", "1; mode=block")
        #expect(conn.getRespHeader("X-Frame-Options") == "DENY")
        #expect(conn.getRespHeader("X-Content-Type-Options") == "nosniff")
        #expect(conn.getRespHeader("X-XSS-Protection") == "1; mode=block")
    }

    @Test("header helpers preserve immutability")
    func test_headerHelpers_immutability_originalUnchanged() {
        let original = TestConnection.build(path: "/")
        let modified = original.putRespHeader("X-Custom", "value")
        #expect(original.getRespHeader("X-Custom") == nil)
        #expect(modified.getRespHeader("X-Custom") == "value")
    }

    @Test("setting header to empty string is valid")
    func test_putRespHeader_emptyValue_isValid() {
        let conn = TestConnection.build(path: "/")
            .putRespHeader("X-Empty", "")
        #expect(conn.getRespHeader("X-Empty") == "")
    }
}
