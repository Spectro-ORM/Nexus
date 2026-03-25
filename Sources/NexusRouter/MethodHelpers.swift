import HTTPTypes
import Nexus

/// Creates a route that matches GET requests to the given path.
///
/// - Parameters:
///   - path: The path pattern to match (e.g., `"/health"`, `"/users/:id"`).
///   - handler: The plug invoked when the route matches.
/// - Returns: A ``Route`` for GET requests to `path`.
public func GET(_ path: String, _ handler: @escaping Plug) -> Route {
    Route(method: .get, path: path, handler: handler)
}

/// Creates a route that matches POST requests to the given path.
///
/// - Parameters:
///   - path: The path pattern to match (e.g., `"/users"`).
///   - handler: The plug invoked when the route matches.
/// - Returns: A ``Route`` for POST requests to `path`.
public func POST(_ path: String, _ handler: @escaping Plug) -> Route {
    Route(method: .post, path: path, handler: handler)
}

/// Creates a route that matches PUT requests to the given path.
///
/// - Parameters:
///   - path: The path pattern to match (e.g., `"/users/:id"`).
///   - handler: The plug invoked when the route matches.
/// - Returns: A ``Route`` for PUT requests to `path`.
public func PUT(_ path: String, _ handler: @escaping Plug) -> Route {
    Route(method: .put, path: path, handler: handler)
}

/// Creates a route that matches DELETE requests to the given path.
///
/// - Parameters:
///   - path: The path pattern to match (e.g., `"/users/:id"`).
///   - handler: The plug invoked when the route matches.
/// - Returns: A ``Route`` for DELETE requests to `path`.
public func DELETE(_ path: String, _ handler: @escaping Plug) -> Route {
    Route(method: .delete, path: path, handler: handler)
}

/// Creates a route that matches PATCH requests to the given path.
///
/// - Parameters:
///   - path: The path pattern to match (e.g., `"/users/:id"`).
///   - handler: The plug invoked when the route matches.
/// - Returns: A ``Route`` for PATCH requests to `path`.
public func PATCH(_ path: String, _ handler: @escaping Plug) -> Route {
    Route(method: .patch, path: path, handler: handler)
}
