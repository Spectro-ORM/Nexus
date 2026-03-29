import Testing
@testable import Nexus
import NexusTest

@Suite("Nested Assigns")
struct NestedAssignsTests {

    // MARK: - Dot-path set / get

    @Test("assign dotPath single segment works like flat assign")
    func test_assignDotPath_singleSegment_likeFlat() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "name", value: "Alice")
        #expect(conn.assigns["name"] as? String == "Alice")
        #expect(conn.value(forDotPath: "name") as? String == "Alice")
    }

    @Test("assign dotPath two levels creates nested dict")
    func test_assignDotPath_twoLevels_createsNested() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "user.name", value: "Alice")
        let user = conn.assigns["user"] as? [String: any Sendable]
        #expect(user?["name"] as? String == "Alice")
        #expect(conn.value(forDotPath: "user.name") as? String == "Alice")
    }

    @Test("assign dotPath three levels creates deep nest")
    func test_assignDotPath_threeLevels_deep() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "user.settings.theme", value: "dark")
        #expect(conn.value(forDotPath: "user.settings.theme") as? String == "dark")
    }

    @Test("assigning sibling keys preserves other branches")
    func test_assignDotPath_siblingKeys_preservesBranches() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "user.name", value: "Alice")
            .assign(dotPath: "user.role", value: "admin")
        #expect(conn.value(forDotPath: "user.name") as? String == "Alice")
        #expect(conn.value(forDotPath: "user.role") as? String == "admin")
    }

    @Test("overwriting a nested key replaces the value")
    func test_assignDotPath_overwrite_replacesValue() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "user.name", value: "Alice")
            .assign(dotPath: "user.name", value: "Bob")
        #expect(conn.value(forDotPath: "user.name") as? String == "Bob")
    }

    // MARK: - Array-path set / get

    @Test("assign path array single element is flat assign")
    func test_assignPath_singleElement_isFlat() {
        let conn = TestConnection.build(path: "/")
            .assign(path: ["color"], value: "blue")
        #expect(conn.assigns["color"] as? String == "blue")
        #expect(conn.value(forPath: ["color"]) as? String == "blue")
    }

    @Test("assign path array creates nested structure")
    func test_assignPath_twoElements_nested() {
        let conn = TestConnection.build(path: "/")
            .assign(path: ["product", "price"], value: 99.99)
        #expect(conn.value(forPath: ["product", "price"]) as? Double == 99.99)
    }

    @Test("assign path array deep nesting works")
    func test_assignPath_threeElements_deep() {
        let conn = TestConnection.build(path: "/")
            .assign(path: ["a", "b", "c"], value: 42)
        #expect(conn.value(forPath: ["a", "b", "c"]) as? Int == 42)
    }

    // MARK: - Edge cases

    @Test("empty dotPath returns receiver unchanged")
    func test_assignDotPath_empty_noChange() {
        let conn = TestConnection.build(path: "/")
        let result = conn.assign(dotPath: "", value: "unused")
        #expect(result.assigns.count == 0)
    }

    @Test("empty path array returns receiver unchanged")
    func test_assignPath_empty_noChange() {
        let conn = TestConnection.build(path: "/")
        let result = conn.assign(path: [], value: "unused")
        #expect(result.assigns.count == 0)
    }

    @Test("value forDotPath missing path returns nil")
    func test_valueDotPath_missingPath_returnsNil() {
        let conn = TestConnection.build(path: "/")
        #expect(conn.value(forDotPath: "a.b.c") == nil)
    }

    @Test("value forDotPath traversal through non-dict returns nil")
    func test_valueDotPath_traversalThroughScalar_returnsNil() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "user", value: "scalar")
        #expect(conn.value(forDotPath: "user.name") == nil)
    }

    @Test("value forPath empty array returns nil")
    func test_valueForPath_empty_returnsNil() {
        let conn = TestConnection.build(path: "/")
        #expect(conn.value(forPath: []) == nil)
    }

    @Test("assign dotPath ignores empty segments")
    func test_assignDotPath_extraDots_ignoredSegments() {
        let conn = TestConnection.build(path: "/")
            .assign(dotPath: "a..b", value: "x")
        // "a..b" splits to ["a", "b"] after filtering empty segments
        #expect(conn.value(forDotPath: "a.b") as? String == "x")
    }

    // MARK: - Immutability

    @Test("assign dotPath preserves original")
    func test_assignDotPath_immutability_originalUnchanged() {
        let original = TestConnection.build(path: "/")
        let modified = original.assign(dotPath: "key", value: "value")
        #expect(original.assigns.isEmpty)
        #expect(modified.assigns["key"] as? String == "value")
    }

    // MARK: - Mixed with flat assigns

    @Test("flat and nested assigns coexist")
    func test_mixed_flatAndNested_coexist() {
        let conn = TestConnection.build(path: "/")
            .assign(key: "flat", value: "yes")
            .assign(dotPath: "nested.key", value: "deep")
        #expect(conn.assigns["flat"] as? String == "yes")
        #expect(conn.value(forDotPath: "nested.key") as? String == "deep")
    }
}
