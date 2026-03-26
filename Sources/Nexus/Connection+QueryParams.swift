import Foundation

// MARK: - Query Parameters

extension Connection {

    /// Query parameters parsed from the request URL.
    ///
    /// Parses the query string portion of ``request``'s path on each access.
    /// For duplicate keys, the first value wins (matching Elixir Plug's
    /// `fetch_query_params` semantics). Both keys and values are
    /// percent-decoded.
    ///
    /// Returns an empty dictionary if there is no query string.
    public var queryParams: [String: String] {
        guard let path = request.path,
              let queryStart = path.firstIndex(of: "?") else {
            return [:]
        }
        let queryString = path[path.index(after: queryStart)...]
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard let key = parts.first else { continue }
            let rawKey = String(key).removingPercentEncoding ?? String(key)
            let rawValue: String
            if parts.count > 1 {
                rawValue = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            } else {
                rawValue = ""
            }
            if params[rawKey] == nil {
                params[rawKey] = rawValue
            }
        }
        return params
    }
}
