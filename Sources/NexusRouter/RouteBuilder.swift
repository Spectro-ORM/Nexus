/// A result builder that collects ``Route`` values into an array.
///
/// Used with ``Router/init(_:)`` to declare routes using a DSL:
///
/// ```swift
/// let router = Router {
///     GET("/health") { conn in
///         conn.respond(status: .ok, body: .string("OK"))
///     }
///     POST("/users") { conn in
///         conn.respond(status: .created, body: .string("created"))
///     }
/// }
/// ```
@resultBuilder
public enum RouteBuilder {

    /// Combines multiple route components declared in a builder block.
    ///
    /// - Parameter components: The route arrays from each expression or control-flow branch.
    /// - Returns: A flat array containing all routes.
    public static func buildBlock(_ components: [Route]...) -> [Route] {
        components.flatMap { $0 }
    }

    /// Wraps a single route expression into an array for uniform handling.
    ///
    /// - Parameter expression: A single route.
    /// - Returns: An array containing the route.
    public static func buildExpression(_ expression: Route) -> [Route] {
        [expression]
    }

    /// Supports optional routes in `if` statements without an `else`.
    ///
    /// - Parameter component: The routes if the condition is true, or `nil`.
    /// - Returns: The routes, or an empty array.
    public static func buildOptional(_ component: [Route]?) -> [Route] {
        component ?? []
    }

    /// Supports the first branch of an `if`/`else` statement.
    ///
    /// - Parameter component: The routes from the first branch.
    /// - Returns: The routes, unchanged.
    public static func buildEither(first component: [Route]) -> [Route] {
        component
    }

    /// Supports the second branch of an `if`/`else` statement.
    ///
    /// - Parameter component: The routes from the second branch.
    /// - Returns: The routes, unchanged.
    public static func buildEither(second component: [Route]) -> [Route] {
        component
    }

    /// Supports `for`-`in` loops in the builder.
    ///
    /// - Parameter components: An array of route arrays from each iteration.
    /// - Returns: All routes flattened into a single array.
    public static func buildArray(_ components: [[Route]]) -> [Route] {
        components.flatMap { $0 }
    }
}
