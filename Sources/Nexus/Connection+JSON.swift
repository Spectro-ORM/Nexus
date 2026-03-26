import Foundation
import HTTPTypes

// MARK: - JSON Decoding

extension Connection {

    /// Decodes the buffered request body as JSON into the given type.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode into.
    ///   - decoder: The JSON decoder to use. Defaults to a stock `JSONDecoder()`.
    /// - Returns: The decoded value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the body is empty,
    ///   not buffered, or contains invalid JSON.
    public func decode<T: Decodable & Sendable>(
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard case .buffered(let data) = requestBody else {
            throw NexusHTTPError(.badRequest, message: "Missing request body")
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NexusHTTPError(
                .badRequest,
                message: "Invalid JSON: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - JSON Encoding

extension Connection {

    /// Encodes the given value as JSON, sets it as the response body with
    /// `Content-Type: application/json`, and halts the connection.
    ///
    /// Unlike ``respond(status:body:)`` which replaces the entire response,
    /// this method preserves existing response headers and only sets the
    /// status, body, content-type header, and halt flag.
    ///
    /// - Parameters:
    ///   - status: The HTTP response status. Defaults to `.ok`.
    ///   - value: The `Encodable` value to serialize as JSON.
    ///   - encoder: The JSON encoder to use. Defaults to a stock `JSONEncoder()`.
    /// - Returns: A halted connection with the JSON response body.
    /// - Throws: `EncodingError` if the value cannot be encoded.
    public func json<T: Encodable & Sendable>(
        status: HTTPResponse.Status = .ok,
        value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Connection {
        let data = try encoder.encode(value)
        var copy = self
        copy.response.status = status
        copy.response.headerFields[.contentType] = "application/json"
        copy.responseBody = .buffered(data)
        copy.isHalted = true
        return copy
    }
}
