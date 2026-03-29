import Foundation
import Testing
import HTTPTypes
@testable import Nexus

@Suite("MethodOverride Plug")
struct MethodOverrideTests {

    let plug = methodOverride()

    // MARK: - Valid Overrides

    @Test("POST with _method=DELETE becomes DELETE")
    func test_post_methodDelete_becomesDelete() async throws {
        let conn = postWithForm("_method=DELETE")
        let result = try await plug(conn)
        #expect(result.request.method == .delete)
    }

    @Test("POST with _method=PUT becomes PUT")
    func test_post_methodPut_becomesPut() async throws {
        let conn = postWithForm("_method=PUT")
        let result = try await plug(conn)
        #expect(result.request.method == .put)
    }

    @Test("POST with _method=PATCH becomes PATCH")
    func test_post_methodPatch_becomesPatch() async throws {
        let conn = postWithForm("_method=PATCH")
        let result = try await plug(conn)
        #expect(result.request.method == .patch)
    }

    // MARK: - Case Insensitive

    @Test("POST with _method=delete (lowercase) works")
    func test_post_methodLowercase_works() async throws {
        let conn = postWithForm("_method=delete")
        let result = try await plug(conn)
        #expect(result.request.method == .delete)
    }

    @Test("POST with _method=Put (mixed case) works")
    func test_post_methodMixedCase_works() async throws {
        let conn = postWithForm("_method=Put")
        let result = try await plug(conn)
        #expect(result.request.method == .put)
    }

    // MARK: - No Override

    @Test("POST with no _method stays POST")
    func test_post_noMethod_staysPost() async throws {
        let conn = postWithForm("name=Alice")
        let result = try await plug(conn)
        #expect(result.request.method == .post)
    }

    // MARK: - Disallowed Overrides

    @Test("POST with _method=GET stays POST")
    func test_post_methodGet_staysPost() async throws {
        let conn = postWithForm("_method=GET")
        let result = try await plug(conn)
        #expect(result.request.method == .post)
    }

    @Test("POST with _method=OPTIONS stays POST")
    func test_post_methodOptions_staysPost() async throws {
        let conn = postWithForm("_method=OPTIONS")
        let result = try await plug(conn)
        #expect(result.request.method == .post)
    }

    @Test("POST with _method=HEAD stays POST")
    func test_post_methodHead_staysPost() async throws {
        let conn = postWithForm("_method=HEAD")
        let result = try await plug(conn)
        #expect(result.request.method == .post)
    }

    // MARK: - GET Not Rewritten

    @Test("GET with ?_method=DELETE stays GET")
    func test_get_queryMethodDelete_staysGet() async throws {
        var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/?_method=DELETE")
        let conn = Connection(request: request)
        let result = try await plug(conn)
        #expect(result.request.method == .get)
    }

    // MARK: - Query Param Fallback

    @Test("POST with ?_method=PUT in query and no form body becomes PUT")
    func test_post_queryParamFallback_becomesPut() async throws {
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/?_method=PUT")
        let conn = Connection(request: request, requestBody: .empty)
        let result = try await plug(conn)
        #expect(result.request.method == .put)
    }

    // MARK: - Form Takes Precedence

    @Test("Form param takes precedence over query param")
    func test_formPrecedence_overQuery() async throws {
        var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/?_method=PUT")
        request.headerFields[.contentType] = "application/x-www-form-urlencoded"
        let conn = Connection(request: request, requestBody: .buffered(Data("_method=DELETE".utf8)))
        let result = try await plug(conn)
        #expect(result.request.method == .delete)
    }

    // MARK: - Pipeline Composition

    @Test("Works in a pipeline with other plugs")
    func test_pipeline_composition() async throws {
        let app = pipeline([
            requestId(),
            methodOverride(),
        ])
        let conn = postWithForm("_method=PATCH")
        let result = try await app(conn)
        #expect(result.request.method == .patch)
        #expect(result.assigns["request_id"] != nil)
    }
}

// MARK: - Helpers

private func postWithForm(_ form: String) -> Connection {
    var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/")
    request.headerFields[.contentType] = "application/x-www-form-urlencoded"
    return Connection(request: request, requestBody: .buffered(Data(form.utf8)))
}
