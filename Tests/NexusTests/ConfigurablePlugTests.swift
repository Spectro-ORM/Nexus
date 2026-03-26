import Testing
import Foundation
import HTTPTypes
@testable import Nexus

@Suite("ConfigurablePlug")
struct ConfigurablePlugTests {

    private func makeConnection(path: String = "/") -> Connection {
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: path)
        return Connection(request: request)
    }

    // MARK: - Example Plugs for Testing

    /// A configurable plug that adds security headers.
    struct SecurityHeaders: ConfigurablePlug {
        struct Options: Sendable {
            var includeHSTS: Bool
            var hstsMaxAge: Int
        }

        let includeHSTS: Bool
        let hstsMaxAge: Int

        init(options: Options) throws {
            guard options.hstsMaxAge >= 0 else {
                throw ConfigError.invalidMaxAge
            }
            self.includeHSTS = options.includeHSTS
            self.hstsMaxAge = options.hstsMaxAge
        }

        func call(_ connection: Connection) async throws -> Connection {
            var conn = connection
            conn.response.headerFields[.xContentTypeOptions] = "nosniff"
            if includeHSTS {
                conn.response.headerFields[.strictTransportSecurity] =
                    "max-age=\(hstsMaxAge)"
            }
            return conn
        }

        enum ConfigError: Error {
            case invalidMaxAge
        }
    }

    /// A trivial configurable plug with Void options.
    struct Passthrough: ConfigurablePlug {
        init(options: Void) {}

        func call(_ connection: Connection) async throws -> Connection {
            connection.assign(key: "passthrough", value: true)
        }
    }

    // MARK: - Init / Validation

    @Test("test_configurablePlug_initValidatesOptions")
    func test_configurablePlug_initValidatesOptions() {
        #expect(throws: SecurityHeaders.ConfigError.self) {
            _ = try SecurityHeaders(options: .init(includeHSTS: true, hstsMaxAge: -1))
        }
    }

    @Test("test_configurablePlug_initSucceedsWithValidOptions")
    func test_configurablePlug_initSucceedsWithValidOptions() throws {
        let plug = try SecurityHeaders(options: .init(includeHSTS: true, hstsMaxAge: 3600))
        #expect(plug.includeHSTS == true)
        #expect(plug.hstsMaxAge == 3600)
    }

    // MARK: - Call

    @Test("test_configurablePlug_callProcessesConnection")
    func test_configurablePlug_callProcessesConnection() async throws {
        let plug = try SecurityHeaders(options: .init(includeHSTS: false, hstsMaxAge: 0))
        let result = try await plug.call(makeConnection())
        #expect(result.response.headerFields[.xContentTypeOptions] == "nosniff")
        #expect(result.response.headerFields[.strictTransportSecurity] == nil)
    }

    @Test("test_configurablePlug_callWithHSTS_addsHeader")
    func test_configurablePlug_callWithHSTS_addsHeader() async throws {
        let plug = try SecurityHeaders(options: .init(includeHSTS: true, hstsMaxAge: 31536000))
        let result = try await plug.call(makeConnection())
        #expect(result.response.headerFields[.strictTransportSecurity] == "max-age=31536000")
    }

    // MARK: - asPlug Bridge

    @Test("test_configurablePlug_asPlug_bridgesToPlugType")
    func test_configurablePlug_asPlug_bridgesToPlugType() async throws {
        let plugFn: Plug = try SecurityHeaders(
            options: .init(includeHSTS: true, hstsMaxAge: 3600)
        ).asPlug()
        let result = try await plugFn(makeConnection())
        #expect(result.response.headerFields[.xContentTypeOptions] == "nosniff")
        #expect(result.response.headerFields[.strictTransportSecurity] == "max-age=3600")
    }

    @Test("test_configurablePlug_asPlug_worksInPipeline")
    func test_configurablePlug_asPlug_worksInPipeline() async throws {
        let security: Plug = try SecurityHeaders(
            options: .init(includeHSTS: true, hstsMaxAge: 3600)
        ).asPlug()
        let passthrough: Plug = Passthrough(options: ()).asPlug()

        let app = pipeline([security, passthrough])
        let result = try await app(makeConnection())
        #expect(result.response.headerFields[.xContentTypeOptions] == "nosniff")
        #expect(result.assigns["passthrough"] as? Bool == true)
    }

    @Test("test_configurablePlug_voidOptions_noThrow")
    func test_configurablePlug_voidOptions_noThrow() async throws {
        let plug = Passthrough(options: ())
        let result = try await plug.call(makeConnection())
        #expect(result.assigns["passthrough"] as? Bool == true)
    }
}
