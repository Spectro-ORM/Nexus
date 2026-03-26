import HTTPTypes

// MARK: - Header Helpers

extension Connection {

    /// Returns a copy with the given response header set.
    ///
    /// - Parameters:
    ///   - name: The header field name.
    ///   - value: The header value.
    /// - Returns: A new connection with the header set.
    public func putRespHeader(_ name: HTTPField.Name, _ value: String) -> Connection {
        var copy = self
        copy.response.headerFields[name] = value
        return copy
    }

    /// Returns a copy with the given response header removed.
    ///
    /// - Parameter name: The header field name to remove.
    /// - Returns: A new connection without the header.
    public func deleteRespHeader(_ name: HTTPField.Name) -> Connection {
        var copy = self
        copy.response.headerFields[name] = nil
        return copy
    }

    /// Returns the value of a request header, or `nil` if not present.
    ///
    /// - Parameter name: The header field name.
    /// - Returns: The header value, or `nil`.
    public func getReqHeader(_ name: HTTPField.Name) -> String? {
        request.headerFields[name]
    }

    /// Returns a copy with the `Content-Type` response header set.
    ///
    /// - Parameter contentType: The content type string (e.g., `"text/html"`).
    /// - Returns: A new connection with the content type set.
    public func putRespContentType(_ contentType: String) -> Connection {
        putRespHeader(.contentType, contentType)
    }
}

// MARK: - Status

extension Connection {

    /// Returns a copy with the response status set, without halting.
    ///
    /// Unlike ``respond(status:body:)`` which also sets the body and halts,
    /// this method only changes the status code.
    ///
    /// - Parameter status: The HTTP response status.
    /// - Returns: A new connection with the updated status.
    public func putStatus(_ status: HTTPResponse.Status) -> Connection {
        var copy = self
        copy.response.status = status
        return copy
    }
}

// MARK: - Request Metadata

extension Connection {

    /// The host from the request's authority (e.g., `"example.com"`).
    ///
    /// Extracted from ``request``'s `authority` field. Returns `nil` if
    /// no authority is set.
    public var host: String? {
        request.authority
    }

    /// The URL scheme of the request (e.g., `"https"`).
    public var scheme: String? {
        request.scheme
    }
}
