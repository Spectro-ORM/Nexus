// MARK: - Lifecycle Hooks

extension Connection {

    /// Registers a callback to be invoked just before the response is sent.
    ///
    /// Callbacks are invoked in reverse registration order (LIFO) — the last
    /// registered callback runs first, mirroring Elixir Plug's
    /// `register_before_send` semantics.
    ///
    /// - Parameter callback: A function that may inspect or modify the
    ///   connection's response fields.
    /// - Returns: A new connection with the callback registered.
    public func registerBeforeSend(
        _ callback: @escaping @Sendable (Connection) -> Connection
    ) -> Connection {
        var copy = self
        copy.beforeSend.append(callback)
        return copy
    }

    /// Executes all registered ``beforeSend`` callbacks in LIFO order and
    /// returns the resulting connection with the callback list cleared.
    ///
    /// The server adapter must call this method before serializing the
    /// response. After execution the ``beforeSend`` array is empty,
    /// preventing double-invocation.
    ///
    /// - Returns: The connection after all callbacks have been applied.
    public func runBeforeSend() -> Connection {
        var result = self
        result.beforeSend = []
        for callback in beforeSend.reversed() {
            result = callback(result)
        }
        return result
    }
}
