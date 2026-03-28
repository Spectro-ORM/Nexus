import Foundation

/// A file extracted from a `multipart/form-data` request body.
///
/// Each file part has a ``filename`` from the `Content-Disposition` header,
/// an optional ``contentType`` from the part's `Content-Type` header,
/// and the raw file ``data``.
public struct MultipartFile: Sendable, Equatable {

    /// The original filename from the `Content-Disposition` header.
    public let filename: String

    /// The MIME type from the part's `Content-Type` header, if present.
    public let contentType: String?

    /// The raw file data.
    public let data: Data

    /// Creates a multipart file.
    ///
    /// - Parameters:
    ///   - filename: The original filename.
    ///   - contentType: The part's MIME type.
    ///   - data: The raw file bytes.
    public init(filename: String, contentType: String?, data: Data) {
        self.filename = filename
        self.contentType = contentType
        self.data = data
    }
}
