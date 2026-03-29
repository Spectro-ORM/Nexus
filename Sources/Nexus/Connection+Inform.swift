import HTTPTypes

/// A queued informational (1xx) HTTP response.
///
/// Informational responses are sent before the final response. The primary
/// use case is HTTP 103 Early Hints, which allows browsers to preload
/// resources while the server computes the final response.
public struct InformationalResponse: Sendable {

    /// The informational status code (must be in the 1xx range).
    public let status: HTTPResponse.Status

    /// Headers to include in the informational response.
    public let headers: HTTPFields

    /// Creates an informational response.
    ///
    /// - Parameters:
    ///   - status: An informational status code (1xx).
    ///   - headers: Headers for the informational response.
    public init(status: HTTPResponse.Status, headers: HTTPFields) {
        self.status = status
        self.headers = headers
    }
}

// MARK: - Informational Responses

extension Connection {

    private static let informationalResponsesKey = "_nexus_informational_responses"

    /// Queues an informational (1xx) response to send before the final response.
    ///
    /// Used primarily for HTTP 103 Early Hints to allow browsers to preload
    /// resources while the server computes the final response.
    ///
    /// ```swift
    /// GET("/page") { conn in
    ///     let conn = conn.inform(
    ///         status: HTTPResponse.Status(code: 103),
    ///         headers: [:]
    ///     )
    ///     let page = try await renderExpensivePage()
    ///     return try conn.html(page)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - status: An informational status (1xx). Non-1xx values are ignored.
    ///   - headers: Headers to include in the informational response.
    /// - Returns: The connection with the informational response queued.
    public func inform(
        status: HTTPResponse.Status,
        headers: HTTPFields
    ) -> Connection {
        guard (100...199).contains(status.code) else { return self }
        var responses = informationalResponses
        responses.append(InformationalResponse(status: status, headers: headers))
        return assign(key: Self.informationalResponsesKey, value: responses)
    }

    /// The queued informational responses, in order of registration.
    ///
    /// The server adapter reads this property to send 1xx responses before
    /// the final response.
    public var informationalResponses: [InformationalResponse] {
        (assigns[Self.informationalResponsesKey] as? [InformationalResponse]) ?? []
    }
}
