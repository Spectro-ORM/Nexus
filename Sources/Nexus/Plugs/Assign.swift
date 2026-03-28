/// Creates a plug that injects a value into ``Connection/assigns`` under
/// the given key.
///
/// Use this to thread shared services (database repos, API clients, config)
/// through the pipeline so that downstream plugs and route handlers read
/// them from the connection rather than capturing external references.
///
/// ```swift
/// let pipeline = pipeline([
///     assign("spectro", value: spectro),
///     routerPlug,
/// ])
/// ```
///
/// - Parameters:
///   - key: The string key to store the value under.
///   - value: A `Sendable` value to inject.
/// - Returns: A plug that assigns the value and passes the connection through.
public func assign<T: Sendable>(
    _ key: String,
    value: T
) -> Plug {
    { conn in
        conn.assign(key: key, value: value)
    }
}

/// Creates a plug that injects a lazily-evaluated value into
/// ``Connection/assigns`` under the given key.
///
/// The closure is called once per request. This is useful when the injected
/// value should be freshly constructed for each connection (e.g., a
/// per-request transaction scope).
///
/// ```swift
/// let pipeline = pipeline([
///     assign("db") { DatabaseTransaction() },
///     routerPlug,
/// ])
/// ```
///
/// - Parameters:
///   - key: The string key to store the value under.
///   - value: A closure that produces the value to inject.
/// - Returns: A plug that assigns the value and passes the connection through.
public func assign<T: Sendable>(
    _ key: String,
    value: @escaping @Sendable () -> T
) -> Plug {
    { conn in
        conn.assign(key: key, value: value())
    }
}
