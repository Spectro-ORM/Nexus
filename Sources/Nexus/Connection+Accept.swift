import HTTPTypes

// MARK: - Content Negotiation

extension Connection {

    /// Returns `true` if the client's `Accept` header indicates it accepts
    /// the given MIME type (or `*/*`).
    ///
    /// - Parameter mimeType: The MIME type to check, e.g. `"text/html"`.
    public func accepts(_ mimeType: String) -> Bool {
        guard let accept = getReqHeader(.accept) else { return true }
        return accept.contains(mimeType) || accept.contains("*/*")
    }

    /// Returns `true` if the client prefers HTML over JSON.
    ///
    /// Browsers send `Accept: text/html,...` first. API clients (curl, Postman,
    /// fetch with `Content-Type: application/json`) send `application/json` first
    /// or omit `text/html` entirely.
    ///
    /// The preference is determined by which type appears first in the `Accept`
    /// header. Falls back to `false` (JSON) when neither is present.
    public var prefersHTML: Bool {
        guard let accept = getReqHeader(.accept) else { return false }
        let htmlRange = accept.range(of: "text/html")
        let jsonRange = accept.range(of: "application/json")
        switch (htmlRange, jsonRange) {
        case let (h?, j?): return h.lowerBound < j.lowerBound
        case (.some, nil): return true
        default:           return false
        }
    }

    /// Responds with HTML or JSON depending on what the client prefers.
    ///
    /// Mirrors Rails' `respond_to` pattern. Browsers receive the HTML variant;
    /// API clients receive the JSON variant.
    ///
    /// ```swift
    /// GET("/donuts") { conn in
    ///     let donuts = try await Donut.all(db: db)
    ///     return try conn.respondTo(
    ///         html: { renderDonutList(conn: conn, donuts: donuts) },
    ///         json: { try conn.json(value: donuts) }
    ///     )
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - html: Closure that builds the HTML response.
    ///   - json: Closure that builds the JSON response (may throw).
    /// - Returns: Whichever response the client prefers.
    public func respondTo(
        html: () throws -> Connection,
        json: () throws -> Connection
    ) throws -> Connection {
        prefersHTML ? try html() : try json()
    }
}
