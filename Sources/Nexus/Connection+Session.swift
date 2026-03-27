import Foundation

// MARK: - Session Helpers

extension Connection {

    /// The assigns key used to store session data.
    public static let sessionKey = "_nexus_session"

    /// The assigns key that signals the session cookie should be deleted.
    static let sessionDropKey = "_nexus_session_drop"

    /// The assigns key that tracks whether the session was read or written.
    static let sessionTouchedKey = "_nexus_session_touched"

    /// The current session dictionary, or an empty dictionary if no session
    /// has been established.
    var sessionData: [String: String] {
        assigns[Connection.sessionKey] as? [String: String] ?? [:]
    }

    /// Reads a value from the session.
    ///
    /// - Parameter key: The session key to look up.
    /// - Returns: The value associated with the key, or `nil` if not present.
    public func getSession(_ key: String) -> String? {
        sessionData[key]
    }

    /// Writes a key–value pair to the session.
    ///
    /// The updated session is serialized back to the session cookie by the
    /// ``sessionPlug(_:)`` plug's `beforeSend` callback.
    ///
    /// - Parameters:
    ///   - key: The session key.
    ///   - value: The value to store.
    /// - Returns: A new connection with the updated session.
    public func putSession(key: String, value: String) -> Connection {
        var session = sessionData
        session[key] = value
        return assign(key: Connection.sessionKey, value: session)
            .assign(key: Connection.sessionTouchedKey, value: true)
    }

    /// Removes a single key from the session.
    ///
    /// - Parameter key: The session key to remove.
    /// - Returns: A new connection with the key removed from the session.
    public func deleteSession(_ key: String) -> Connection {
        var session = sessionData
        session.removeValue(forKey: key)
        return assign(key: Connection.sessionKey, value: session)
            .assign(key: Connection.sessionTouchedKey, value: true)
    }

    /// Removes all session data and marks the session cookie for deletion.
    ///
    /// The ``sessionPlug(_:)`` plug's `beforeSend` callback will emit a
    /// `Set-Cookie` header with `Max-Age=0` to instruct the browser to
    /// remove the cookie.
    ///
    /// - Returns: A new connection with the session cleared.
    public func clearSession() -> Connection {
        assign(key: Connection.sessionKey, value: [String: String]())
            .assign(key: Connection.sessionDropKey, value: true)
            .assign(key: Connection.sessionTouchedKey, value: true)
    }
}
