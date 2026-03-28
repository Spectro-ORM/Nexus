import Foundation

// MARK: - Multipart Form Data

extension Connection {

    /// Parses the buffered request body as `multipart/form-data`.
    ///
    /// Extracts the boundary from the `Content-Type` header and parses
    /// all parts into text fields and file uploads.
    ///
    /// ```swift
    /// POST("/upload") { conn in
    ///     let parts = try conn.multipartParams()
    ///     let name = parts.field("name")          // String?
    ///     let avatar = parts.file("avatar")       // MultipartFile?
    ///     return try conn.json(value: ["file": avatar?.filename ?? "none"])
    /// }
    /// ```
    ///
    /// - Returns: Parsed multipart parameters containing text fields and files.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the body is not
    ///   buffered, `Content-Type` is not `multipart/form-data`, the boundary
    ///   is missing, or the body is malformed.
    public func multipartParams() throws -> MultipartParams {
        guard case .buffered(let data) = requestBody else {
            throw NexusHTTPError(.badRequest, message: "Missing request body")
        }

        guard let contentType = request.headerFields[.contentType],
              contentType.lowercased().contains("multipart/form-data") else {
            throw NexusHTTPError(
                .badRequest,
                message: "Content-Type is not multipart/form-data"
            )
        }

        guard let boundary = MultipartParser.extractBoundary(from: contentType) else {
            throw NexusHTTPError(
                .badRequest,
                message: "Missing boundary in Content-Type"
            )
        }

        return try MultipartParser.parse(data: data, boundary: boundary)
    }
}
