import Foundation

/// Parsed result from a `multipart/form-data` request body.
///
/// Separates text fields from file uploads. Access values with
/// ``field(_:)`` and ``file(_:)`` convenience methods.
///
/// ```swift
/// let parts = try conn.multipartParams()
/// let name = parts.field("name")          // String?
/// let avatar = parts.file("avatar")       // MultipartFile?
/// ```
public struct MultipartParams: Sendable {

    /// Text field values keyed by field name.
    public let fields: [String: String]

    /// File uploads keyed by field name.
    public let files: [String: MultipartFile]

    /// Creates parsed multipart parameters.
    ///
    /// - Parameters:
    ///   - fields: Text field values.
    ///   - files: File uploads.
    public init(fields: [String: String], files: [String: MultipartFile]) {
        self.fields = fields
        self.files = files
    }

    /// Returns the text value for the given field name.
    ///
    /// - Parameter name: The field name.
    /// - Returns: The field value, or `nil` if not present.
    public func field(_ name: String) -> String? {
        fields[name]
    }

    /// Returns the uploaded file for the given field name.
    ///
    /// - Parameter name: The field name.
    /// - Returns: The file, or `nil` if not present.
    public func file(_ name: String) -> MultipartFile? {
        files[name]
    }
}
