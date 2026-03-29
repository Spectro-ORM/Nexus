import Foundation

// MARK: - Nested Assigns (Dot-Path Access)

extension Connection {

    /// Returns a copy with the given value stored at the dot-separated path.
    ///
    /// Creates intermediate `[String: any Sendable]` dictionaries for any
    /// missing path segments. Existing values at sibling branches are
    /// preserved.
    ///
    /// ```swift
    /// let conn = conn
    ///     .assign(dotPath: "user.name", value: "Alice")
    ///     .assign(dotPath: "user.role", value: "admin")
    ///
    /// conn.value(forDotPath: "user.name")  // "Alice"
    /// conn.value(forDotPath: "user.role")  // "admin"
    /// ```
    ///
    /// - Parameters:
    ///   - dotPath: A dot-separated key path (e.g., `"user.profile.bio"`).
    ///     Empty segments are ignored.
    ///   - value: The `Sendable` value to store.
    /// - Returns: A new connection with the value stored at the path.
    public func assign(dotPath: String, value: any Sendable) -> Connection {
        let parts = dotPath.components(separatedBy: ".").filter { !$0.isEmpty }
        guard !parts.isEmpty else { return self }
        return assign(path: parts, value: value)
    }

    /// Returns a copy with the given value stored at the specified key path.
    ///
    /// Creates intermediate `[String: any Sendable]` dictionaries for any
    /// missing path segments.
    ///
    /// ```swift
    /// let conn = conn.assign(path: ["product", "price", "amount"], value: 99.99)
    /// conn.value(forPath: ["product", "price", "amount"])  // 99.99
    /// ```
    ///
    /// - Parameters:
    ///   - path: An ordered array of keys describing the nesting (e.g.,
    ///     `["user", "name"]`). Returns the receiver unchanged if empty.
    ///   - value: The `Sendable` value to store.
    /// - Returns: A new connection with the value stored at the path.
    public func assign(path: [String], value: any Sendable) -> Connection {
        guard !path.isEmpty else { return self }
        var copy = self
        copy.assigns = NestedAssigns.set(in: copy.assigns, path: path, value: value)
        return copy
    }

    /// Retrieves the value stored at the dot-separated path, or `nil` if absent.
    ///
    /// Returns `nil` if any segment along the path is absent or is not a
    /// `[String: any Sendable]` dictionary.
    ///
    /// ```swift
    /// conn.value(forDotPath: "user.settings.theme")  // "dark" or nil
    /// ```
    ///
    /// - Parameter dotPath: A dot-separated key path. Empty segments are ignored.
    /// - Returns: The stored value, or `nil`.
    public func value(forDotPath dotPath: String) -> (any Sendable)? {
        let parts = dotPath.components(separatedBy: ".").filter { !$0.isEmpty }
        return value(forPath: parts)
    }

    /// Retrieves the value stored at the specified key path, or `nil` if absent.
    ///
    /// Returns `nil` if any segment along the path is missing or if an
    /// intermediate value is not a `[String: any Sendable]` dictionary.
    ///
    /// - Parameter path: An ordered array of keys. Returns `nil` if empty.
    /// - Returns: The stored value, or `nil`.
    public func value(forPath path: [String]) -> (any Sendable)? {
        guard let first = path.first else { return nil }
        var current: (any Sendable)? = assigns[first]
        for segment in path.dropFirst() {
            guard let dict = current as? [String: any Sendable] else { return nil }
            current = dict[segment]
        }
        return current
    }
}

// MARK: - Internal Helpers

private enum NestedAssigns {

    /// Recursively sets a value at the given path, creating intermediate
    /// dictionaries as needed.
    static func set(
        in dict: [String: any Sendable],
        path: [String],
        value: any Sendable
    ) -> [String: any Sendable] {
        guard let first = path.first else { return dict }
        var result = dict
        if path.count == 1 {
            result[first] = value
        } else {
            let nested = result[first] as? [String: any Sendable] ?? [:]
            result[first] = set(in: nested, path: Array(path.dropFirst()), value: value)
        }
        return result
    }
}
