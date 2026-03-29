import Foundation
import HTTPTypes

// MARK: - Favicon Plug

/// A plug that serves a static favicon from in-memory data.
///
/// Intercepts requests for the favicon path and responds with the icon.
/// All other requests pass through unchanged.
///
/// ```swift
/// let iconData = try Data(contentsOf: Bundle.main.url(forResource: "favicon", withExtension: "ico")!)
/// let favicon = Favicon(iconData: iconData)
/// let app = pipeline([favicon, router])
/// ```
public struct Favicon: Sendable {

    private let iconData: Data
    private let iconPath: String

    /// Creates a `Favicon` plug with in-memory icon data.
    ///
    /// - Parameters:
    ///   - iconData: The raw bytes of the favicon file (`.ico`, `.png`, or
    ///     `.svg`).
    ///   - iconPath: The request path to intercept. Defaults to
    ///     `"/favicon.ico"`.
    public init(iconData: Data, iconPath: String = "/favicon.ico") {
        self.iconData = iconData
        self.iconPath = iconPath
    }
}

extension Favicon: ModulePlug {

    /// Serves the favicon or passes the request through.
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: A halted `200 OK` with the favicon body when the request
    ///   path matches ``iconPath``; the unmodified connection otherwise.
    public func call(_ connection: Connection) async throws -> Connection {
        guard let requestPath = connection.request.path else {
            return connection
        }

        // Strip query string for comparison.
        let pathWithoutQuery = requestPath.split(separator: "?", maxSplits: 1)
            .first
            .map(String.init) ?? requestPath

        guard pathWithoutQuery == iconPath else {
            return connection
        }

        let contentType = mimeType(for: iconPath)
        var conn = connection
        conn.response = HTTPResponse(status: .ok)
        conn.response.headerFields[.contentType] = contentType
        conn.responseBody = .buffered(iconData)
        conn.isHalted = true
        return conn
    }
}

// MARK: - Helpers

/// Returns the MIME type for a favicon path based on its file extension.
private func mimeType(for path: String) -> String {
    let lower = path.lowercased()
    if lower.hasSuffix(".png") { return "image/png" }
    if lower.hasSuffix(".svg") { return "image/svg+xml" }
    if lower.hasSuffix(".gif") { return "image/gif" }
    if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return "image/jpeg" }
    return "image/x-icon"
}
