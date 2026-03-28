import Foundation
import HTTPTypes

// MARK: - Plaintext Response

extension Connection {

    /// Sets the response body to a plain-text string, sets
    /// `Content-Type: text/plain; charset=utf-8`, and halts the connection.
    ///
    /// ```swift
    /// GET("/health") { conn in
    ///     conn.text("OK")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - body: The text string to send.
    ///   - status: The HTTP response status. Defaults to `.ok`.
    /// - Returns: A halted connection with the plain-text response body.
    public func text(
        _ body: String,
        status: HTTPResponse.Status = .ok
    ) -> Connection {
        var copy = self
        copy.response.status = status
        copy.response.headerFields[.contentType] = "text/plain; charset=utf-8"
        copy.responseBody = .buffered(Data(body.utf8))
        copy.isHalted = true
        return copy
    }
}

// MARK: - XML Response

extension Connection {

    /// Sets the response body to an XML string, sets
    /// `Content-Type: application/xml; charset=utf-8`, and halts the connection.
    ///
    /// ```swift
    /// GET("/feed.xml") { conn in
    ///     conn.xml("<rss>...</rss>")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - body: The XML string to send.
    ///   - status: The HTTP response status. Defaults to `.ok`.
    /// - Returns: A halted connection with the XML response body.
    public func xml(
        _ body: String,
        status: HTTPResponse.Status = .ok
    ) -> Connection {
        var copy = self
        copy.response.status = status
        copy.response.headerFields[.contentType] = "application/xml; charset=utf-8"
        copy.responseBody = .buffered(Data(body.utf8))
        copy.isHalted = true
        return copy
    }
}
