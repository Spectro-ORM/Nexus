import Foundation
import HTTPTypes
import Nexus

// MARK: - PathPattern (Internal)

/// A parsed path pattern that matches against incoming request paths.
///
/// Supports static segments (`/users`) and parameterized segments (`/users/:id`).
struct PathPattern: Sendable {

    /// A single segment in a path pattern.
    enum Segment: Sendable, Equatable {
        /// A literal path segment that must match exactly (e.g., `users`).
        case literal(String)
        /// A parameterized segment that captures any value (e.g., `:id` captures `"42"`).
        case parameter(String)
        /// A catch-all segment that matches the rest of the path (e.g., `*` or `*rest`).
        case wildcard(String?)
    }

    let segments: [Segment]

    /// Parses a path pattern string into segments.
    ///
    /// - Parameter pattern: The path pattern (e.g., `"/users/:id"`).
    init(_ pattern: String) {
        let raw = pattern
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        segments = raw.map { part in
            if part.hasPrefix(":") {
                .parameter(String(part.dropFirst()))
            } else if part == "*" {
                .wildcard(nil)
            } else if part.hasPrefix("*") {
                .wildcard(String(part.dropFirst()))
            } else {
                .literal(part)
            }
        }
    }

    /// Attempts to match the given request path against this pattern.
    ///
    /// Strips query strings before matching. Trailing slashes are ignored.
    ///
    /// - Parameter path: The raw request path string (may include a query string).
    /// - Returns: A dictionary of extracted parameters if the path matches,
    ///   or `nil` if it does not.
    func match(_ path: String) -> [String: String]? {
        let pathWithoutQuery = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        let pathSegments = pathWithoutQuery
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        var params: [String: String] = [:]
        for (index, patternSegment) in segments.enumerated() {
            switch patternSegment {
            case .literal(let expected):
                guard index < pathSegments.count else { return nil }
                guard pathSegments[index] == expected else { return nil }
            case .parameter(let name):
                guard index < pathSegments.count else { return nil }
                guard !pathSegments[index].isEmpty else { return nil }
                params[name] = pathSegments[index].removingPercentEncoding ?? pathSegments[index]
            case .wildcard(let name):
                // Wildcard matches all remaining segments (including zero)
                let rest = pathSegments.dropFirst(index).joined(separator: "/")
                if let name {
                    params[name] = rest
                }
                return params
            }
        }

        // If no wildcard, segment counts must match exactly
        guard pathSegments.count == segments.count else { return nil }
        return params
    }
}

// MARK: - Route

/// A single HTTP route that pairs an HTTP method and path pattern with a
/// handler plug.
///
/// Routes are typically created using the method helper functions
/// (``GET(_:_:)``, ``POST(_:_:)``, ``PUT(_:_:)``, ``DELETE(_:_:)``,
/// ``PATCH(_:_:)``) rather than directly.
public struct Route: Sendable {

    /// The HTTP method this route matches.
    public let method: HTTPRequest.Method

    /// The raw path pattern string (e.g., `"/users/:id"`).
    public let path: String

    /// The plug that handles requests matching this route.
    public let handler: Plug

    /// The parsed path pattern used for matching.
    let pattern: PathPattern

    /// Creates a route from the given method, path pattern, and handler.
    ///
    /// - Parameters:
    ///   - method: The HTTP method to match.
    ///   - path: The path pattern string (e.g., `"/users"`, `"/users/:id"`).
    ///   - handler: The plug to invoke when this route matches.
    public init(method: HTTPRequest.Method, path: String, handler: @escaping Plug) {
        self.method = method
        self.path = path
        self.pattern = PathPattern(path)
        self.handler = handler
    }
}
