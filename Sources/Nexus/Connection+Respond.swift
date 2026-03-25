import HTTPTypes

extension Connection {

    /// Returns a copy of this connection with the response status and body set,
    /// and the connection halted.
    ///
    /// This is a convenience for the common pattern of building a complete
    /// response and stopping the pipeline in a single expression, following
    /// the halt-not-throw contract (ADR-004).
    ///
    /// - Parameters:
    ///   - status: The HTTP response status code.
    ///   - body: The response body. Defaults to `.empty`.
    /// - Returns: A halted connection with the given status and body.
    public func respond(status: HTTPResponse.Status, body: ResponseBody = .empty) -> Connection {
        var copy = self
        copy.response = HTTPResponse(status: status)
        copy.responseBody = body
        copy.isHalted = true
        return copy
    }
}
