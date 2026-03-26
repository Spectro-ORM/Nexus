import Foundation
import HTTPTypes

// MARK: - Chunk Writer

extension Connection {

    /// A handle for writing chunks to a streaming response.
    ///
    /// Wraps an `AsyncThrowingStream` continuation. The writer is `Sendable`
    /// and can be passed across concurrency boundaries.
    public struct ChunkWriter: Sendable {

        private let continuation: AsyncThrowingStream<Data, any Error>.Continuation

        init(continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
            self.continuation = continuation
        }

        /// Writes a data chunk to the response stream.
        ///
        /// - Parameter data: The raw bytes to send.
        public func write(_ data: Data) {
            continuation.yield(data)
        }

        /// Writes a UTF-8 string chunk to the response stream.
        ///
        /// - Parameter string: The string to send, encoded as UTF-8.
        public func write(_ string: String) {
            continuation.yield(Data(string.utf8))
        }

        /// Signals that all chunks have been written.
        ///
        /// After calling this method, no further writes are accepted and the
        /// stream terminates cleanly.
        public func finish() {
            continuation.finish()
        }

        /// Signals an error, terminating the stream.
        ///
        /// - Parameter error: The error that caused the stream to end.
        public func finish(throwing error: any Error) {
            continuation.finish(throwing: error)
        }
    }
}

// MARK: - Streaming Response

extension Connection {

    /// Returns a halted connection with a streaming response body.
    ///
    /// The `handler` closure receives a ``ChunkWriter`` and is responsible for
    /// writing data chunks and calling ``ChunkWriter/finish()`` when done.
    /// The closure runs in an unstructured `Task` so that the response headers
    /// can be sent to the client immediately.
    ///
    /// ```swift
    /// conn
    ///     .putRespContentType("text/event-stream")
    ///     .sendChunked { writer in
    ///         for i in 1...5 {
    ///             writer.write(sseEvent(data: "tick \(i)"))
    ///             try await Task.sleep(for: .seconds(1))
    ///         }
    ///         writer.finish()
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - status: The HTTP response status. Defaults to `.ok`.
    ///   - handler: An async closure that writes chunks via the writer.
    /// - Returns: A halted connection with a streaming response body.
    public func sendChunked(
        status: HTTPResponse.Status = .ok,
        handler: @escaping @Sendable (ChunkWriter) async throws -> Void
    ) -> Connection {
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            let writer = ChunkWriter(continuation: continuation)
            Task {
                do {
                    try await handler(writer)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        var copy = self
        copy.response.status = status
        copy.responseBody = .stream(stream)
        copy.isHalted = true
        return copy
    }
}
