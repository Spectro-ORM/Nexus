// MARK: - Typed Path Parameters

extension Connection {

    /// The well-known ``assigns`` key where path parameters are stored.
    public static let pathParamsKey = "_nexus_path_params"

    /// Path parameters extracted by the router from the matched route pattern.
    ///
    /// For a route pattern like `/users/:id`, after matching `/users/42` this
    /// property returns `["id": "42"]`.
    ///
    /// - Returns: A dictionary of parameter names to their captured values,
    ///   or an empty dictionary if no parameters have been set.
    public var params: [String: String] {
        assigns[Self.pathParamsKey] as? [String: String] ?? [:]
    }

    /// Returns a copy of this connection with the given path parameters merged
    /// into the ``params`` dictionary.
    ///
    /// Existing parameters with the same key are overwritten.
    ///
    /// - Parameter newParams: The parameters to merge.
    /// - Returns: A new connection with updated params.
    public func mergeParams(_ newParams: [String: String]) -> Connection {
        var existing = params
        for (key, value) in newParams {
            existing[key] = value
        }
        return assign(key: Self.pathParamsKey, value: existing)
    }
}
