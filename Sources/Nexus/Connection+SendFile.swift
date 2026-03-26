import Foundation
import HTTPTypes

// MARK: - File Serving

extension Connection {

    /// Returns a halted connection that streams the contents of a file as
    /// the response body.
    ///
    /// The file is read in chunks using `FileHandle`, which avoids loading the
    /// entire file into memory at once. The `Content-Type` header is inferred
    /// from the file extension when not provided explicitly.
    ///
    /// > Important: This method does **not** validate the path against
    /// > directory traversal attacks. Callers that serve user-provided paths
    /// > must sanitize the input before calling `sendFile`.
    ///
    /// ```swift
    /// // Serve a static asset
    /// return try conn.sendFile(path: "/var/www/index.html")
    /// ```
    ///
    /// - Parameters:
    ///   - path: The absolute file system path to the file.
    ///   - contentType: The MIME type. When `nil`, inferred from the file
    ///     extension via a built-in mapping. Defaults to `nil`.
    ///   - chunkSize: The number of bytes per stream chunk. Defaults to
    ///     65 536 (64 KB).
    /// - Returns: A halted connection with a streaming response body and
    ///   the `Content-Type` header set.
    /// - Throws: ``NexusHTTPError`` with `.notFound` if the file does not
    ///   exist, or `.internalServerError` if the file cannot be opened.
    public func sendFile(
        path: String,
        contentType: String? = nil,
        chunkSize: Int = 65_536
    ) throws -> Connection {
        guard FileManager.default.fileExists(atPath: path) else {
            throw NexusHTTPError(.notFound, message: "File not found")
        }
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw NexusHTTPError(.internalServerError, message: "Cannot open file")
        }

        let resolvedContentType: String
        if let contentType {
            resolvedContentType = contentType
        } else {
            let ext = (path as NSString).pathExtension
            resolvedContentType = mimeType(forExtension: ext)
        }

        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            continuation.onTermination = { _ in
                fileHandle.closeFile()
            }
            Task {
                do {
                    while true {
                        let data = fileHandle.readData(ofLength: chunkSize)
                        if data.isEmpty { break }
                        continuation.yield(data)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        var copy = self
        copy.response.status = .ok
        copy.response.headerFields[.contentType] = resolvedContentType
        copy.responseBody = .stream(stream)
        copy.isHalted = true
        return copy
    }
}
