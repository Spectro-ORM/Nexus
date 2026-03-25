import Testing
import HTTPTypes
import Nexus
@testable import NexusRouter

@Suite("Router")
struct RouterTests {

    private func makeConnection(method: HTTPRequest.Method = .get, path: String = "/") -> Connection {
        let request = HTTPRequest(method: method, scheme: "https", authority: "example.com", path: path)
        return Connection(request: request)
    }

    @Test("test_router_handle_passesConnectionThrough")
    func test_router_handle_passesConnectionThrough() async throws {
        let router = Router(plug: { $0 })
        let result = try await router.handle(makeConnection())
        #expect(result.isHalted == false)
    }

    @Test("test_router_handle_propagatesHalt")
    func test_router_handle_propagatesHalt() async throws {
        let router = Router(plug: { conn in conn.halted() })
        let result = try await router.handle(makeConnection())
        #expect(result.isHalted == true)
    }

    @Test("test_router_handle_propagatesThrow")
    func test_router_handle_propagatesThrow() async {
        struct TestError: Error {}
        let router = Router(plug: { _ in throw TestError() })
        await #expect(throws: TestError.self) {
            try await router.handle(makeConnection())
        }
    }
}
