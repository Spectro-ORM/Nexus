import Foundation
import HTTPTypes

/// A plug that enforces HTTP Basic authentication.
///
/// Parses the `Authorization: Basic <base64>` header and calls the
/// provided `validate` closure with the decoded username and password.
/// If validation fails or the header is missing/malformed, responds
/// with 401 Unauthorized and a `WWW-Authenticate` challenge header.
///
/// ```swift
/// let auth = basicAuth { username, password in
///     username == "admin" && password == "secret"
/// }
/// let app = pipeline([auth, router])
/// ```
///
/// - Parameters:
///   - realm: The authentication realm for the `WWW-Authenticate` header.
///     Defaults to `"Nexus"`.
///   - validate: A closure that receives `(username, password)` and returns
///     `true` if credentials are valid.
/// - Returns: A plug that enforces Basic authentication.
public func basicAuth(
    realm: String = "Nexus",
    validate: @escaping @Sendable (String, String) async throws -> Bool
) -> Plug {
    { conn in
        guard let authHeader = conn.request.headerFields[.authorization] else {
            return denyAccess(conn, realm: realm)
        }

        guard authHeader.hasPrefix("Basic "),
              let encoded = authHeader.split(separator: " ", maxSplits: 1).last,
              let data = Data(base64Encoded: String(encoded)),
              let decoded = String(data: data, encoding: .utf8) else {
            return denyAccess(conn, realm: realm)
        }

        let parts = decoded.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else {
            return denyAccess(conn, realm: realm)
        }

        let username = String(parts[0])
        let password = String(parts[1])

        guard try await validate(username, password) else {
            return denyAccess(conn, realm: realm)
        }

        return conn
            .assign(key: "basic_auth_username", value: username)
    }
}

private func denyAccess(_ conn: Connection, realm: String) -> Connection {
    var copy = conn
    copy.response.status = .unauthorized
    copy.response.headerFields[HTTPField.Name("WWW-Authenticate")!] =
        "Basic realm=\"\(realm)\""
    copy.responseBody = .string("Unauthorized")
    copy.isHalted = true
    return copy
}
