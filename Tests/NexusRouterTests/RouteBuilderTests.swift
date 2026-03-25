import Testing
import HTTPTypes
import Nexus
@testable import NexusRouter

@Suite("RouteBuilder")
struct RouteBuilderTests {

    @Test("test_routeBuilder_singleRoute_returnsOneElementArray")
    func test_routeBuilder_singleRoute_returnsOneElementArray() {
        @RouteBuilder var routes: [Route] {
            GET("/health") { conn in conn }
        }
        #expect(routes.count == 1)
        #expect(routes[0].method == .get)
    }

    @Test("test_routeBuilder_multipleRoutes_returnsAllRoutes")
    func test_routeBuilder_multipleRoutes_returnsAllRoutes() {
        @RouteBuilder var routes: [Route] {
            GET("/a") { conn in conn }
            POST("/b") { conn in conn }
            DELETE("/c") { conn in conn }
        }
        #expect(routes.count == 3)
        #expect(routes[0].method == .get)
        #expect(routes[1].method == .post)
        #expect(routes[2].method == .delete)
    }

    @Test("test_routeBuilder_conditionalRoute_includedWhenTrue")
    func test_routeBuilder_conditionalRoute_includedWhenTrue() {
        let includeAdmin = true
        @RouteBuilder var routes: [Route] {
            GET("/health") { conn in conn }
            if includeAdmin {
                GET("/admin") { conn in conn }
            }
        }
        #expect(routes.count == 2)
    }

    @Test("test_routeBuilder_conditionalRoute_excludedWhenFalse")
    func test_routeBuilder_conditionalRoute_excludedWhenFalse() {
        let includeAdmin = false
        @RouteBuilder var routes: [Route] {
            GET("/health") { conn in conn }
            if includeAdmin {
                GET("/admin") { conn in conn }
            }
        }
        #expect(routes.count == 1)
    }
}

@Suite("Method Helpers")
struct MethodHelperTests {

    @Test("test_GET_createsRouteWithGetMethod")
    func test_GET_createsRouteWithGetMethod() {
        let route = GET("/health") { conn in conn }
        #expect(route.method == .get)
        #expect(route.path == "/health")
    }

    @Test("test_POST_createsRouteWithPostMethod")
    func test_POST_createsRouteWithPostMethod() {
        let route = POST("/users") { conn in conn }
        #expect(route.method == .post)
        #expect(route.path == "/users")
    }

    @Test("test_PUT_createsRouteWithPutMethod")
    func test_PUT_createsRouteWithPutMethod() {
        let route = PUT("/users/:id") { conn in conn }
        #expect(route.method == .put)
        #expect(route.path == "/users/:id")
    }

    @Test("test_DELETE_createsRouteWithDeleteMethod")
    func test_DELETE_createsRouteWithDeleteMethod() {
        let route = DELETE("/users/:id") { conn in conn }
        #expect(route.method == .delete)
        #expect(route.path == "/users/:id")
    }

    @Test("test_PATCH_createsRouteWithPatchMethod")
    func test_PATCH_createsRouteWithPatchMethod() {
        let route = PATCH("/users/:id") { conn in conn }
        #expect(route.method == .patch)
        #expect(route.path == "/users/:id")
    }

    @Test("test_HEAD_createsRouteWithHeadMethod")
    func test_HEAD_createsRouteWithHeadMethod() {
        let route = HEAD("/health") { conn in conn }
        #expect(route.method == .head)
        #expect(route.path == "/health")
    }

    @Test("test_OPTIONS_createsRouteWithOptionsMethod")
    func test_OPTIONS_createsRouteWithOptionsMethod() {
        let route = OPTIONS("/users") { conn in conn }
        #expect(route.method == .options)
        #expect(route.path == "/users")
    }
}
