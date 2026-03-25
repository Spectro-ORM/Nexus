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
///         let id = conn.assigns["id"] as! String
///         conn.respond(status: .ok, body: .string("User \(id)"))
///     }
/// }
/// ```
public struct Router: Sendable {

    private let routes: [Route]

    /// Creates a router from routes declared with the ``RouteBuilder`` DSL.
    ///
    /// Routes are checked in declaration order; the first match wins.
    ///
    /// - Parameter routes: A result builder closure that declares the routes.
    public init(@RouteBuilder _ routes: () -> [Route]) {
        self.routes = routes()
    }

    /// Dispatches the connection to the first matching route.
    ///
    /// Path parameters extracted from the route pattern (e.g., `:id`) are
    /// injected into the connection's ``Connection/assigns`` dictionary before
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
                    var conn = connection
                    for (key, value) in params {
                        conn = conn.assign(key: key, value: value)
                    }
                    return try await route.handler(conn)
                } else {
                    pathMatchedButMethodDidNot = true
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
