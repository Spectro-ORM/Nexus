import Foundation

/// Represents the body of an HTTP request.
///
/// Use `.empty` when there is no body, `.buffered` when the full body is
/// available as a `Data` value, and `.stream` when the body is delivered
/// incrementally as an async sequence of `Data` chunks.
public enum RequestBody: Sendable {
    /// No request body.
    case empty

    /// A fully buffered request body.
    case buffered(Data)

    /// A streaming request body delivered as successive `Data` chunks.
    case stream(AsyncThrowingStream<Data, any Error>)
}

/// Represents the body of an HTTP response.
///
/// Use `.empty` when there is no body, `.buffered` when the full body is
/// available as a `Data` value, and `.stream` when the body is produced
/// incrementally as an async sequence of `Data` chunks.
public enum ResponseBody: Sendable {
    /// No response body.
    case empty

    /// A fully buffered response body.
    case buffered(Data)

    /// A streaming response body produced as successive `Data` chunks.
    case stream(AsyncThrowingStream<Data, any Error>)
}

// MARK: - Convenience

extension ResponseBody {

    /// Creates a `.buffered` response body from a UTF-8 encoded string.
    ///
    /// - Parameter string: The string to encode.
    /// - Returns: A `.buffered` body, or `.empty` if the string cannot be encoded.
    public static func string(_ string: String) -> ResponseBody {
        guard let data = string.data(using: .utf8) else { return .empty }
        return .buffered(data)
    }
}
