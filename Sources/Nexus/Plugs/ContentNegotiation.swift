import HTTPTypes

// MARK: - ContentNegotiation Plug

/// A plug that performs HTTP content negotiation against an `Accept` header.
///
/// Compares the client's `Accept` header against the server's list of
/// supported MIME types (respecting quality values). Returns
/// `406 Not Acceptable` when no supported type is acceptable to the client.
///
/// On success, the negotiated MIME type is stored in the connection assigns
/// under ``NegotiatedTypeKey``:
///
/// ```swift
/// let negotiation = ContentNegotiation(supported: ["application/json", "text/html"])
/// let app = pipeline([negotiation, router])
///
/// // In a handler:
/// let mime = conn[ContentNegotiation.NegotiatedTypeKey.self]  // "application/json"
/// ```
public struct ContentNegotiation: Sendable {

    /// The assign key for the negotiated MIME type.
    ///
    /// Read from within a downstream plug or handler after the
    /// `ContentNegotiation` plug has run:
    ///
    /// ```swift
    /// if let mime = conn[ContentNegotiation.NegotiatedTypeKey.self] {
    ///     // Set response Content-Type accordingly
    /// }
    /// ```
    public enum NegotiatedTypeKey: AssignKey {
        public typealias Value = String
    }

    private let supported: [String]
    private let defaultType: String?

    /// Creates a `ContentNegotiation` plug.
    ///
    /// - Parameters:
    ///   - supported: Ordered list of MIME types the server can produce
    ///     (e.g., `["application/json", "text/html"]`). Checked in order;
    ///     the first match against the client's `Accept` header wins.
    ///   - defaultType: MIME type to use when no `Accept` header is present.
    ///     Defaults to the first element of `supported`.
    public init(supported: [String], defaultType: String? = nil) {
        self.supported = supported
        self.defaultType = defaultType
    }
}

extension ContentNegotiation: ModulePlug {

    /// Negotiates content type and stores the result in assigns.
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The connection with the negotiated type in assigns, or a
    ///   halted `406 Not Acceptable` response if no match is found.
    public func call(_ connection: Connection) async throws -> Connection {
        let acceptHeader = connection.request.headerFields[.accept]

        guard let accept = acceptHeader, !accept.isEmpty else {
            let chosen = defaultType ?? supported.first ?? "*/*"
            return connection.assign(NegotiatedTypeKey.self, value: chosen)
        }

        let accepted = parseAcceptHeader(accept)
        if let match = bestMatch(accepted: accepted, supported: supported) {
            return connection.assign(NegotiatedTypeKey.self, value: match)
        }

        return connection.respond(
            status: .notAcceptable,
            body: .string("Not Acceptable: supported types are \(supported.joined(separator: ", "))")
        )
    }
}

// MARK: - Accept Header Parsing

/// Parses an `Accept` header value into (MIME type, quality) pairs.
///
/// Pairs are sorted by quality descending. Invalid quality values default to 1.0.
private func parseAcceptHeader(_ accept: String) -> [(type: String, q: Double)] {
    accept.split(separator: ",").compactMap { part in
        let segments = part.trimmingCharacters(in: .whitespaces).split(separator: ";")
        guard let typeStr = segments.first else { return nil }
        let mimeType = typeStr.trimmingCharacters(in: .whitespaces)
        var quality = 1.0
        for segment in segments.dropFirst() {
            let kv = segment.trimmingCharacters(in: .whitespaces)
            if kv.hasPrefix("q="), let q = Double(kv.dropFirst(2)) {
                quality = q
            }
        }
        return (type: mimeType, q: quality)
    }.sorted { $0.q > $1.q }
}

/// Returns the first supported type that the client accepts.
///
/// Supports exact matches, wildcard subtypes (`application/*`), and the
/// catch-all `*/*`.
private func bestMatch(accepted: [(type: String, q: Double)], supported: [String]) -> String? {
    for entry in accepted {
        guard entry.q > 0 else { continue }
        for supportedType in supported {
            if entry.type == "*/*" { return supportedType }
            if entry.type == supportedType { return supportedType }
            let aParts = entry.type.split(separator: "/")
            let sParts = supportedType.split(separator: "/")
            if aParts.count == 2, sParts.count == 2,
               aParts[0] == sParts[0], aParts[1] == "*" {
                return supportedType
            }
        }
    }
    return nil
}
