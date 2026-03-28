import Foundation
import HTTPTypes

// MARK: - HTML Response

extension Connection {

    /// Sets the response body to an HTML string, sets `Content-Type: text/html; charset=utf-8`,
    /// and halts the connection.
    ///
    /// Unlike ``respond(status:body:)`` which replaces the entire response,
    /// this method preserves existing response headers and only sets the
    /// status, body, content-type header, and halt flag.
    ///
    /// - Parameters:
    ///   - body: The HTML string to send as the response body.
    ///   - status: The HTTP response status. Defaults to `.ok`.
    /// - Returns: A halted connection with the HTML response body.
    public func html(
        _ body: String,
        status: HTTPResponse.Status = .ok
    ) -> Connection {
        var copy = self
        copy.response.status = status
        copy.response.headerFields[.contentType] = "text/html; charset=utf-8"
        copy.responseBody = .buffered(Data(body.utf8))
        copy.isHalted = true
        return copy
    }
}

// MARK: - Layout Convenience

extension Connection {

    /// Renders a content block and wraps it in a layout template.
    ///
    /// Reduces boilerplate when every page is wrapped in a shared layout.
    /// Instead of:
    /// ```swift
    /// let body = _renderUserProfileBuffer(user: user)
    /// return renderLayout(conn: conn, title: user.name, content: body)
    /// ```
    /// You can write:
    /// ```swift
    /// return conn.html(title: user.name, layout: renderLayout) {
    ///     _renderUserProfileBuffer(user: user)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - title: The page title, forwarded as the first parameter to `layout`.
    ///   - layout: The generated layout function, e.g. `renderLayout`.
    ///   - content: A closure that returns the inner HTML string (call a buffer function here).
    /// - Returns: A halted connection with the fully-wrapped HTML response.
    public func html(
        title: String,
        layout: (Connection, String, String) -> Connection,
        content: () -> String
    ) -> Connection {
        let body = content()
        return layout(self, title, body)
    }
}
