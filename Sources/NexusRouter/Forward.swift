import Nexus
import HTTPTypes

/// Delegates requests matching a path prefix to another router.
///
/// Strips the prefix from the request path before dispatching to the
/// target router, so the sub-router's routes are relative to the prefix.
///
/// ```swift
/// let apiRouter = Router {
///     GET("/users") { conn in conn.json(value: ["users": []]) }
/// }
/// let app = Router {
///     GET("/health") { conn in conn.respond(status: .ok) }
///     forward("/api", to: apiRouter)
/// }
/// // GET /api/users → dispatches to apiRouter's GET /users
/// ```
///
/// - Parameters:
///   - prefix: The path prefix to match and strip (e.g., `"/api"`).
///   - router: The sub-router to delegate to.
/// - Returns: A route array entry that the ``RouteBuilder`` can accept.
public func forward(_ prefix: String, to router: Router) -> [Route] {
    let normalizedPrefix = prefix.hasSuffix("/")
        ? String(prefix.dropLast())
        : prefix

    // A single catch-all route that matches any path starting with the prefix
    let handler: Plug = { conn in
        let originalPath = conn.request.path ?? "/"
        let prefixWithSlash = normalizedPrefix + "/"

        // Check if the path starts with our prefix
        guard originalPath == normalizedPrefix || originalPath.hasPrefix(prefixWithSlash) else {
            return conn
        }

        // Strip the prefix from the path for the sub-router
        var copy = conn
        if originalPath == normalizedPrefix {
            copy.request.path = "/"
        } else {
            copy.request.path = String(originalPath.dropFirst(normalizedPrefix.count))
        }

        let result = try await router.handle(copy)

        // Restore the original path on the result
        var final = result
        final.request.path = originalPath
        return final
    }

    // Use a wildcard route that matches the prefix itself and anything under it
    return [
        Route(method: .get, path: normalizedPrefix + "/*", handler: handler),
        Route(method: .post, path: normalizedPrefix + "/*", handler: handler),
        Route(method: .put, path: normalizedPrefix + "/*", handler: handler),
        Route(method: .delete, path: normalizedPrefix + "/*", handler: handler),
        Route(method: .patch, path: normalizedPrefix + "/*", handler: handler),
        Route(method: .head, path: normalizedPrefix + "/*", handler: handler),
        Route(method: .options, path: normalizedPrefix + "/*", handler: handler),
    ]
}
