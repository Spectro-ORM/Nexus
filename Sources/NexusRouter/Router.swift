import Nexus
import HTTPTypes

/// A result-builder-based HTTP router that dispatches incoming requests to
/// the appropriate ``Plug`` based on method and path.
///
/// The router checks routes in declaration order and invokes the first match.
/// If no route matches, it returns a 404 Not Found response. If the path
/// matches but the HTTP method does not, it returns 405 Method Not Allowed.
///
/// ## Usage
///
/// ```swift
/// let router = Router {
///     GET("/health") { conn in
///         conn.respond(status: .ok, body: .string("OK"))
///     }
///     POST("/users") { conn in
///         conn.respond(status: .created, body: .string("created"))
///     }
///     GET("/users/:id") { conn in
///         let id = conn.params["id"] ?? ""
///         return conn.respond(status: .ok, body: .string("User \(id)"))
///     }
/// }
/// ```
public struct Router: Sendable, ModulePlug {

    private let routes: [Route]

    /// Creates a router from routes declared with the ``RouteBuilder`` DSL.
    ///
    /// Routes are checked in declaration order; the first match wins.
    ///
    /// - Parameter routes: A result builder closure that declares the routes.
    public init(@RouteBuilder _ routes: () -> [Route]) {
        self.routes = routes()
    }

    /// Calls ``handle(_:)`` so the router can be used directly as a ``Plug``.
    ///
    /// ```swift
    /// let app = pipe(logger, router)
    /// ```
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The connection after routing.
    /// - Throws: Any infrastructure error thrown by the matched route's handler.
    public func callAsFunction(_ connection: Connection) async throws -> Connection {
        try await handle(connection)
    }

    /// Satisfies ``ModulePlug`` so the router can be used with ``.asPlug()``.
    ///
    /// ```swift
    /// let app = pipeline([auth.asPlug(), router.asPlug()])
    /// ```
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The connection after routing.
    /// - Throws: Any infrastructure error thrown by the matched route's handler.
    public func call(_ connection: Connection) async throws -> Connection {
        try await handle(connection)
    }

    /// Dispatches the connection to the first matching route.
    ///
    /// Path parameters extracted from the route pattern (e.g., `:id`) are
    /// injected into the connection's ``Connection/params`` dictionary before
    /// the handler is called.
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The connection after processing by the matched route handler,
    ///   or a halted 404/405 response if no route matches.
    /// - Throws: Any infrastructure error thrown by the matched route's handler.
    public func handle(_ connection: Connection) async throws -> Connection {
        let requestPath = connection.request.path ?? "/"
        let requestMethod = connection.request.method

        var pathMatchedButMethodDidNot = false

        for route in routes {
            if let params = route.pattern.match(requestPath) {
                if route.method == requestMethod {
                    let conn = params.isEmpty
                        ? connection
                        : connection.mergeParams(params)
                    return try await route.handler(conn)
                } else {
                    pathMatchedButMethodDidNot = true
                }
            }
        }

        // RFC 9110 §9.3.2: HEAD should mirror GET without a body.
        // Fall back to a matching GET route if no explicit HEAD route matched.
        if requestMethod == .head {
            for route in routes where route.method == .get {
                if let params = route.pattern.match(requestPath) {
                    let conn = params.isEmpty
                        ? connection
                        : connection.mergeParams(params)
                    var result = try await route.handler(conn)
                    result.responseBody = .empty
                    return result
                }
            }
        }

        if pathMatchedButMethodDidNot {
            return connection.respond(
                status: .methodNotAllowed,
                body: .string("Method Not Allowed")
            )
        }

        return connection.respond(status: .notFound, body: .string("Not Found"))
    }
}
