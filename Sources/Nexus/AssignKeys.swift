/// Typed key for the unique request ID assigned by ``requestId(generator:headerName:)``.
public enum RequestIdKey: AssignKey {
    public typealias Value = String
}

/// Typed key for the session dictionary managed by the session plug.
public enum SessionKey: AssignKey {
    public typealias Value = [String: String]
}

/// Typed key for the remote IP address populated by the server adapter.
public enum RemoteIPKey: AssignKey {
    public typealias Value = String
}
