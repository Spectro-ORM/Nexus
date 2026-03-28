import Foundation
import HTTPTypes

// MARK: - Raw Data Response

extension Connection {

    /// Sets the response body to raw data with the given content type
    /// and halts the connection.
    ///
    /// Use this for binary payloads (images, PDFs, protobuf, etc.)
    /// where the caller knows the exact content type.
    ///
    /// ```swift
    /// GET("/avatar.png") { conn in
    ///     let png = try loadAvatar()
    ///     return conn.data(png, contentType: "image/png")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - body: The raw data to send.
    ///   - contentType: The MIME type string (e.g. `"image/png"`).
    ///   - status: The HTTP response status. Defaults to `.ok`.
    /// - Returns: A halted connection with the data response body.
    public func data(
        _ body: Data,
        contentType: String,
        status: HTTPResponse.Status = .ok
    ) -> Connection {
        var copy = self
        copy.response.status = status
        copy.response.headerFields[.contentType] = contentType
        copy.responseBody = .buffered(body)
        copy.isHalted = true
        return copy
    }
}
