import Foundation
import HTTPTypes

/// A plug that generates a unique request ID for each connection.
///
/// Sets the `X-Request-Id` response header and stores the ID in
/// ``Connection/assigns`` under the key `"request_id"`.
///
/// ```swift
/// let app = pipeline([requestId(), logger, router])
/// ```
///
/// - Parameter generator: A closure that produces a unique ID string.
///   Defaults to `UUID().uuidString`.
/// - Parameter headerName: The response header name. Defaults to `"X-Request-Id"`.
/// - Returns: A plug that assigns a unique request ID.
public func requestId(
    generator: @escaping @Sendable () -> String = { UUID().uuidString },
    headerName: String = "X-Request-Id"
) -> Plug {
    { conn in
        let id = generator()
        var copy = conn.assign(key: "request_id", value: id)
        if let field = HTTPField.Name(headerName) {
            copy.response.headerFields[field] = id
        }
        return copy
    }
}
