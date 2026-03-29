import Testing
@testable import Nexus
import NexusTest

@Suite("Route Parameters Access")
struct RouteParamsTests {

    // MARK: - pathParameters

    @Test("pathParameters is empty with no params")
    func test_pathParameters_empty_noParams() {
        let conn = TestConnection.build(path: "/users")
        #expect(conn.pathParameters.isEmpty)
    }

    @Test("pathParameters mirrors params")
    func test_pathParameters_mirrors_params() {
        let conn = TestConnection.build(path: "/users/42")
            .mergeParams(["id": "42"])
        #expect(conn.pathParameters["id"] == "42")
        #expect(conn.pathParameters["id"] == conn.params["id"])
    }

    // MARK: - queryParameters (multi-value)

    @Test("queryParameters single value")
    func test_queryParameters_singleValue_parsedCorrectly() {
        let conn = TestConnection.build(path: "/items?page=2")
        #expect(conn.queryParameters["page"] == ["2"])
    }

    @Test("queryParameters multiple values same key")
    func test_queryParameters_duplicateKeys_preservedAsArray() {
        let conn = TestConnection.build(path: "/items?tag=swift&tag=concurrency")
        let tags = conn.queryParameters["tag"]
        #expect(tags?.count == 2)
        #expect(tags?.contains("swift") == true)
        #expect(tags?.contains("concurrency") == true)
    }

    @Test("queryParameters empty when no query string")
    func test_queryParameters_noQueryString_empty() {
        let conn = TestConnection.build(path: "/users")
        #expect(conn.queryParameters.isEmpty)
    }

    @Test("queryParameters percent-decodes keys and values")
    func test_queryParameters_percentDecoding_applied() {
        let conn = TestConnection.build(path: "/search?q=hello%20world")
        #expect(conn.queryParameters["q"] == ["hello world"])
    }

    @Test("queryParameters key with no value gives empty string")
    func test_queryParameters_keyWithNoValue_emptyString() {
        let conn = TestConnection.build(path: "/items?flag")
        #expect(conn.queryParameters["flag"] == [""])
    }

    // MARK: - parameters (combined)

    @Test("parameters combines path and query")
    func test_parameters_combines_pathAndQuery() {
        let conn = TestConnection.build(path: "/users/42?format=json")
            .mergeParams(["id": "42"])
        #expect(conn.parameters["id"] == ["42"])
        #expect(conn.parameters["format"] == ["json"])
    }

    @Test("parameters path params take precedence over query params")
    func test_parameters_pathTakesPrecedence_overQuery() {
        let conn = TestConnection.build(path: "/users/42?id=999")
            .mergeParams(["id": "42"])
        // Path params win
        #expect(conn.parameters["id"] == ["42"])
    }

    // MARK: - getParameter

    @Test("getParameter returns path param first")
    func test_getParameter_pathParamFirst() {
        let conn = TestConnection.build(path: "/users/42?id=999")
            .mergeParams(["id": "42"])
        #expect(conn.getParameter("id") == "42")
    }

    @Test("getParameter falls back to query param")
    func test_getParameter_fallsBack_toQuery() {
        let conn = TestConnection.build(path: "/items?sort=name")
        #expect(conn.getParameter("sort") == "name")
    }

    @Test("getParameter returns nil for absent param")
    func test_getParameter_absent_returnsNil() {
        let conn = TestConnection.build(path: "/items")
        #expect(conn.getParameter("missing") == nil)
    }

    // MARK: - getParameters

    @Test("getParameters returns all query values")
    func test_getParameters_multipleValues() {
        let conn = TestConnection.build(path: "/items?tag=a&tag=b&tag=c")
        let tags = conn.getParameters("tag")
        #expect(tags.count == 3)
        #expect(tags.contains("a") && tags.contains("b") && tags.contains("c"))
    }

    @Test("getParameters returns empty array for absent param")
    func test_getParameters_absent_returnsEmptyArray() {
        let conn = TestConnection.build(path: "/items")
        #expect(conn.getParameters("missing").isEmpty)
    }

    // MARK: - typed parameter extraction

    @Test("getParameter as Int converts correctly")
    func test_getParameter_asInt_converts() {
        let conn = TestConnection.build(path: "/items?page=5")
        let page: Int? = conn.getParameter("page", as: Int.self)
        #expect(page == 5)
    }

    @Test("getParameter as Double converts correctly")
    func test_getParameter_asDouble_converts() {
        let conn = TestConnection.build(path: "/items?price=9.99")
        let price: Double? = conn.getParameter("price", as: Double.self)
        #expect(price == 9.99)
    }

    @Test("getParameter as Int returns nil for non-numeric")
    func test_getParameter_asInt_nonNumericReturnsNil() {
        let conn = TestConnection.build(path: "/items?page=abc")
        let page: Int? = conn.getParameter("page", as: Int.self)
        #expect(page == nil)
    }

    @Test("getParameter as Bool converts true")
    func test_getParameter_asBool_convertsTrueString() {
        let conn = TestConnection.build(path: "/items?active=true")
        let active: Bool? = conn.getParameter("active", as: Bool.self)
        #expect(active == true)
    }

    @Test("getParameter typed returns nil for absent param")
    func test_getParameter_typed_absentReturnsNil() {
        let conn = TestConnection.build(path: "/items")
        let val: Int? = conn.getParameter("missing", as: Int.self)
        #expect(val == nil)
    }
}
