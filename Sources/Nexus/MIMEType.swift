/// Returns the MIME type for a file extension.
///
/// Covers common web content types. Returns `"application/octet-stream"`
/// for unrecognized extensions.
///
/// - Parameter ext: The file extension without the leading dot (e.g. `"html"`).
/// - Returns: The corresponding MIME type string.
func mimeType(forExtension ext: String) -> String {
    switch ext.lowercased() {
    case "html", "htm": return "text/html"
    case "css": return "text/css"
    case "js", "mjs": return "text/javascript"
    case "json": return "application/json"
    case "xml": return "application/xml"
    case "txt": return "text/plain"
    case "csv": return "text/csv"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "svg": return "image/svg+xml"
    case "webp": return "image/webp"
    case "ico": return "image/x-icon"
    case "pdf": return "application/pdf"
    case "zip": return "application/zip"
    case "wasm": return "application/wasm"
    case "woff": return "font/woff"
    case "woff2": return "font/woff2"
    case "ttf": return "font/ttf"
    case "otf": return "font/otf"
    default: return "application/octet-stream"
    }
}
