import Nexus

/// Creates a group of routes that share a common path prefix.
///
/// Routes declared inside the builder closure have `prefix` prepended to
/// their paths. Scopes can be nested — the prefixes compound.
///
/// ```swift
/// let router = Router {
///     scope("/api") {
///         GET("/users") { conn in conn.respond(status: .ok, body: .string("[]")) }
///         scope("/v2") {
///             GET("/users") { conn in conn.respond(status: .ok, body: .string("v2")) }
///         }
///     }
/// }
/// // Matches: /api/users, /api/v2/users
/// ```
///
/// - Parameters:
///   - prefix: The path prefix to prepend to all nested routes (e.g., `"/api"`).
///   - routes: A result builder closure that declares the routes within this scope.
/// - Returns: An array of routes with the prefix applied to their paths.
public func scope(
    _ prefix: String,
    @RouteBuilder _ routes: () -> [Route]
) -> [Route] {
    let normalizedPrefix = prefix.hasSuffix("/")
        ? String(prefix.dropLast())
        : prefix
    return routes().map { route in
        Route(
            method: route.method,
            path: normalizedPrefix + route.path,
            handler: route.handler
        )
    }
}

/// Creates a group of routes that share a common path prefix and middleware
/// pipeline.
///
/// Each route's handler is wrapped with the given middleware plugs, applied
/// in order before the handler runs. This is the Nexus equivalent of
/// Phoenix's `pipe_through`.
///
/// ```swift
/// let auth: Plug = { conn in /* verify token */ }
/// let router = Router {
///     scope("/api", through: [auth]) {
///         GET("/users") { conn in conn.respond(status: .ok, body: .string("[]")) }
///     }
/// }
/// ```
///
/// Nested scopes with middleware compose correctly — inner middleware wraps
/// first, outer middleware wraps second, giving the expected
/// `outer → inner → handler` execution order.
///
/// - Parameters:
///   - prefix: The path prefix to prepend to all nested routes.
///   - middleware: An ordered list of plugs to apply before each route's handler.
///   - routes: A result builder closure that declares the routes within this scope.
/// - Returns: An array of routes with the prefix and middleware applied.
public func scope(
    _ prefix: String,
    through middleware: [Plug],
    @RouteBuilder _ routes: () -> [Route]
) -> [Route] {
    let normalizedPrefix = prefix.hasSuffix("/")
        ? String(prefix.dropLast())
        : prefix
    return routes().map { route in
        let wrapped: Plug = middleware.isEmpty
            ? route.handler
            : pipeline(middleware + [route.handler])
        return Route(
            method: route.method,
            path: normalizedPrefix + route.path,
            handler: wrapped
        )
    }
}

/// Creates a group of routes that share a common path prefix and a
/// named middleware pipeline.
///
/// ```swift
/// let apiPipeline = NamedPipeline { requestId(); auth }
///
/// scope("/api", through: apiPipeline) {
///     GET("/users") { conn in ... }
/// }
/// ```
///
/// - Parameters:
///   - prefix: The path prefix to prepend to all nested routes.
///   - pipeline: A named pipeline containing the ordered list of plugs.
///   - routes: A result builder closure that declares the routes within this scope.
/// - Returns: An array of routes with the prefix and pipeline applied.
public func scope(
    _ prefix: String,
    through pipeline: NamedPipeline,
    @RouteBuilder _ routes: () -> [Route]
) -> [Route] {
    scope(prefix, through: [pipeline.asPlug()], routes)
}
