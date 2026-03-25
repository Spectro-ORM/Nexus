import Testing
@testable import NexusRouter

@Suite("PathPattern")
struct PathPatternTests {

    // MARK: - Static Paths

    @Test("test_pathPattern_staticRoot_matchesSlash")
    func test_pathPattern_staticRoot_matchesSlash() {
        let pattern = PathPattern("/")
        let result = pattern.match("/")
        #expect(result != nil)
        #expect(result?.isEmpty == true)
    }

    @Test("test_pathPattern_staticRoot_doesNotMatchOtherPaths")
    func test_pathPattern_staticRoot_doesNotMatchOtherPaths() {
        let pattern = PathPattern("/")
        #expect(pattern.match("/users") == nil)
    }

    @Test("test_pathPattern_staticSingleSegment_matchesExactPath")
    func test_pathPattern_staticSingleSegment_matchesExactPath() {
        let pattern = PathPattern("/health")
        let result = pattern.match("/health")
        #expect(result != nil)
        #expect(result?.isEmpty == true)
    }

    @Test("test_pathPattern_staticSingleSegment_doesNotMatchDifferentPath")
    func test_pathPattern_staticSingleSegment_doesNotMatchDifferentPath() {
        let pattern = PathPattern("/health")
        #expect(pattern.match("/users") == nil)
    }

    @Test("test_pathPattern_staticMultiSegment_matchesExactPath")
    func test_pathPattern_staticMultiSegment_matchesExactPath() {
        let pattern = PathPattern("/api/v1/users")
        let result = pattern.match("/api/v1/users")
        #expect(result != nil)
        #expect(result?.isEmpty == true)
    }

    @Test("test_pathPattern_staticPath_matchesWithTrailingSlash")
    func test_pathPattern_staticPath_matchesWithTrailingSlash() {
        let pattern = PathPattern("/health")
        let result = pattern.match("/health/")
        #expect(result != nil)
    }

    @Test("test_pathPattern_staticPath_stripsQueryString")
    func test_pathPattern_staticPath_stripsQueryString() {
        let pattern = PathPattern("/users")
        let result = pattern.match("/users?page=1&limit=10")
        #expect(result != nil)
    }

    // MARK: - Parameterized Paths

    @Test("test_pathPattern_singleParam_capturesValue")
    func test_pathPattern_singleParam_capturesValue() {
        let pattern = PathPattern("/users/:id")
        let result = pattern.match("/users/42")
        #expect(result?["id"] == "42")
    }

    @Test("test_pathPattern_multipleParams_capturesAllValues")
    func test_pathPattern_multipleParams_capturesAllValues() {
        let pattern = PathPattern("/users/:userId/posts/:postId")
        let result = pattern.match("/users/7/posts/99")
        #expect(result?["userId"] == "7")
        #expect(result?["postId"] == "99")
    }

    @Test("test_pathPattern_mixedSegments_capturesOnlyParams")
    func test_pathPattern_mixedSegments_capturesOnlyParams() {
        let pattern = PathPattern("/api/users/:id")
        let result = pattern.match("/api/users/abc")
        #expect(result != nil)
        #expect(result?.count == 1)
        #expect(result?["id"] == "abc")
    }

    @Test("test_pathPattern_param_doesNotMatchWrongSegmentCount")
    func test_pathPattern_param_doesNotMatchWrongSegmentCount() {
        let pattern = PathPattern("/users/:id")
        #expect(pattern.match("/users") == nil)
        #expect(pattern.match("/users/42/extra") == nil)
    }

    // MARK: - Edge Cases

    @Test("test_pathPattern_emptyPath_treatedAsRoot")
    func test_pathPattern_emptyPath_treatedAsRoot() {
        let pattern = PathPattern("/")
        let result = pattern.match("")
        #expect(result != nil)
    }

    @Test("test_pathPattern_paramWithQueryString_capturesAndStripsQuery")
    func test_pathPattern_paramWithQueryString_capturesAndStripsQuery() {
        let pattern = PathPattern("/users/:id")
        let result = pattern.match("/users/42?expand=true")
        #expect(result?["id"] == "42")
    }
}
