import Testing
import HTTPTypes
import Nexus
@testable import NexusRouter

@Suite("ANY Route Helper")
struct AnyRouteTests {

    private func makeConnection(
        method: HTTPRequest.Method = .get,
        path: String = "/"
    ) -> Connection {
        let request = HTTPRequest(method: method, scheme: "https", authority: "example.com", path: path)
        return Connection(request: request)
    }

    @Test("test_ANY_createsRoutesForAllMethods")
    func test_ANY_createsRoutesForAllMethods() {
        let routes = ANY("/catch-all") { conn in conn }
        #expect(routes.count == 7)
        let methods = Set(routes.map(\.method))
        #expect(methods.contains(.get))
        #expect(methods.contains(.post))
        #expect(methods.contains(.put))
        #expect(methods.contains(.delete))
        #expect(methods.contains(.patch))
        #expect(methods.contains(.head))
        #expect(methods.contains(.options))
    }

    @Test("test_ANY_worksInRouterDSL")
    func test_ANY_worksInRouterDSL() async throws {
        let router = Router {
            ANY("/echo") { conn in
                conn.respond(status: .ok, body: .string("matched"))
            }
        }

        for method: HTTPRequest.Method in [.get, .post, .put, .delete, .patch] {
            let result = try await router.handle(makeConnection(method: method, path: "/echo"))
            #expect(result.response.status == .ok)
        }
    }
}
