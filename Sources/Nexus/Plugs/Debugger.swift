import Foundation
import HTTPTypes

/// Style options for the debug error page.
public enum DebugPageStyle: Sendable {
    /// Built-in styled HTML page with inline CSS.
    case `default`
    /// Plain text output (useful for API-first dev or curl debugging).
    case plainText
}

/// Catches pipeline errors and renders a detailed debug page.
///
/// **Development only.** Never enable in production — it exposes internals.
///
/// This is a wrapper function (like ``rescueErrors(_:)``) that catches
/// errors thrown by the wrapped plug and renders a debug response:
///
/// ```swift
/// let app = debugger(pipeline([
///     requestId(),
///     router,
/// ]))
/// ```
///
/// - Parameters:
///   - plug: The plug or pipeline to wrap.
///   - style: The output format for the error page. Defaults to `.default`.
/// - Returns: A plug that catches errors and renders debug information.
public func debugger(
    _ plug: @escaping Plug,
    style: DebugPageStyle = .default
) -> Plug {
    { conn in
        do {
            return try await plug(conn)
        } catch {
            let statusCode: HTTPResponse.Status
            if let nexusError = error as? NexusHTTPError {
                statusCode = nexusError.status
            } else {
                statusCode = .internalServerError
            }

            let body: String
            switch style {
            case .default:
                body = renderHTMLDebugPage(error: error, conn: conn)
            case .plainText:
                body = renderPlainTextDebugPage(error: error, conn: conn)
            }

            var result = conn
            result.response.status = statusCode
            result.response.headerFields[.contentType] = style == .default
                ? "text/html; charset=utf-8"
                : "text/plain; charset=utf-8"
            result.responseBody = .buffered(Data(body.utf8))
            result.isHalted = true
            return result
        }
    }
}

// MARK: - Redaction

private let redactedPatterns = ["secret", "password", "token", "key"]

private func redactValue(forKey key: String, value: any Sendable) -> String {
    let lower = key.lowercased()
    for pattern in redactedPatterns where lower.contains(pattern) {
        return "[REDACTED]"
    }
    return String(describing: value)
}

// MARK: - HTML Rendering

private func renderHTMLDebugPage(error: any Error, conn: Connection) -> String {
    let errorType = String(describing: type(of: error))
    let errorMessage = String(describing: error)
    let method = conn.request.method.rawValue
    let path = conn.request.path ?? "/"

    var headersHTML = ""
    for field in conn.request.headerFields {
        let name = escapeHTML(field.name.rawName)
        let value = escapeHTML(field.value)
        headersHTML += "<tr><td>\(name)</td><td>\(value)</td></tr>\n"
    }

    var queryHTML = ""
    for (key, value) in conn.queryParams {
        queryHTML += "<tr><td>\(escapeHTML(key))</td><td>\(escapeHTML(value))</td></tr>\n"
    }
    if queryHTML.isEmpty {
        queryHTML = "<tr><td colspan=\"2\"><em>None</em></td></tr>"
    }

    var assignsHTML = ""
    for (key, value) in conn.assigns.sorted(by: { $0.key < $1.key }) {
        let redacted = redactValue(forKey: key, value: value)
        assignsHTML += "<tr><td>\(escapeHTML(key))</td><td>\(escapeHTML(redacted))</td></tr>\n"
    }
    if assignsHTML.isEmpty {
        assignsHTML = "<tr><td colspan=\"2\"><em>None</em></td></tr>"
    }

    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>Nexus Debug — \(escapeHTML(errorType))</title>
    <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #1e1e2e; color: #cdd6f4; font-family: monospace; font-size: 14px; padding: 24px; }
    h1 { color: #f38ba8; font-size: 20px; margin-bottom: 8px; }
    h2 { color: #89b4fa; font-size: 16px; margin: 24px 0 8px; border-bottom: 1px solid #45475a; padding-bottom: 4px; }
    .error-msg { background: #302030; border-left: 4px solid #f38ba8; padding: 12px 16px; margin: 12px 0; white-space: pre-wrap; word-break: break-all; }
    table { width: 100%; border-collapse: collapse; margin: 8px 0; }
    td { padding: 4px 12px; border-bottom: 1px solid #313244; vertical-align: top; }
    td:first-child { color: #a6adc8; width: 30%; }
    .method { color: #a6e3a1; }
    .path { color: #fab387; }
    </style>
    </head>
    <body>
    <h1>\(escapeHTML(errorType))</h1>
    <div class="error-msg">\(escapeHTML(errorMessage))</div>
    <h2>Request</h2>
    <p><span class="method">\(escapeHTML(method))</span> <span class="path">\(escapeHTML(path))</span></p>
    <h2>Request Headers</h2>
    <table>\(headersHTML)</table>
    <h2>Query Parameters</h2>
    <table>\(queryHTML)</table>
    <h2>Assigns</h2>
    <table>\(assignsHTML)</table>
    </body>
    </html>
    """
}

// MARK: - Plain Text Rendering

private func renderPlainTextDebugPage(error: any Error, conn: Connection) -> String {
    let errorType = String(describing: type(of: error))
    let errorMessage = String(describing: error)
    let method = conn.request.method.rawValue
    let path = conn.request.path ?? "/"

    var lines: [String] = []
    lines.append("=== Nexus Debug ===")
    lines.append("")
    lines.append("Error: \(errorType)")
    lines.append("Message: \(errorMessage)")
    lines.append("")
    lines.append("--- Request ---")
    lines.append("\(method) \(path)")
    lines.append("")
    lines.append("--- Headers ---")
    for field in conn.request.headerFields {
        lines.append("\(field.name.rawName): \(field.value)")
    }
    lines.append("")
    lines.append("--- Query Parameters ---")
    let params = conn.queryParams
    if params.isEmpty {
        lines.append("(none)")
    } else {
        for (key, value) in params {
            lines.append("\(key)=\(value)")
        }
    }
    lines.append("")
    lines.append("--- Assigns ---")
    let sorted = conn.assigns.sorted(by: { $0.key < $1.key })
    if sorted.isEmpty {
        lines.append("(none)")
    } else {
        for (key, value) in sorted {
            let redacted = redactValue(forKey: key, value: value)
            lines.append("\(key): \(redacted)")
        }
    }

    return lines.joined(separator: "\n")
}

// MARK: - HTML Escaping

private func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
