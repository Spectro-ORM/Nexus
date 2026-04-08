import Foundation
import HTTPTypes

// MARK: - SSE Stream Helper

/// A sequence that yields Server-Sent Events as UTF-8 encoded data chunks.
///
/// This type bridges SSE's text-based protocol with the `ResponseBody.stream`
/// API, which expects `Data` chunks. Each event is formatted via the
/// ``sseEvent(data:event:id:retry:)`` function and encoded as UTF-8.
@usableFromInline
internal struct SSEEventSequence: Sendable, AsyncSequence {
    public typealias Element = Data

    /// The underlying asynchronous sequence of SSE event components.
    @usableFromInline internal let base: AsyncStream<SSEEvent>

    /// Creates a sequence from an async stream of SSE events.
    ///
    /// - Parameter base: An async stream yielding `SSEEvent` values.
    @inlinable
    init(base: AsyncStream<SSEEvent>) {
        self.base = base
    }

    /// Creates an iterator over the SSE event sequence.
    ///
    /// - Returns: An async iterator that yields UTF-8 encoded event data.
    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator())
    }

    /// An async iterator that converts SSE events to UTF-8 data chunks.
    public struct AsyncIterator: AsyncIteratorProtocol {
        /// The underlying iterator from the `AsyncStream<SSEEvent>`.
        @usableFromInline internal var base: AsyncStream<SSEEvent>.Iterator

        /// Creates an iterator from the base stream's iterator.
        ///
        /// - Parameter base: The iterator from the `AsyncStream<SSEEvent>`.
        @inlinable
        init(base: AsyncStream<SSEEvent>.Iterator) {
            self.base = base
        }

        /// Advances the iterator and returns the next UTF-8 encoded event.
        ///
        /// - Returns: UTF-8 encoded `Data` containing the formatted SSE event,
        ///   or `nil` when the stream terminates.
        @inlinable
        public mutating func next() async throws -> Data? {
            guard let event = await base.next() else {
                return nil
            }
            return event.formatted().data(using: .utf8)
        }
    }
}

// MARK: - SSE Event Model

/// A single Server-Sent Event with optional fields.
///
/// SSE events consist of a required `data` field and optional `event`, `id`,
/// and `retry` fields. This model captures those values for formatting by
/// ``sseEvent(data:event:id:retry:)``.
public struct SSEEvent: Sendable {
    /// The event data. Multi-line data is split across multiple `data:` lines.
    public var data: String

    /// The event type (e.g., `"message"`, `"update"`). Optional.
    public var event: String?

    /// A unique identifier for this event. Optional.
    public var id: String?

    /// The reconnection time in milliseconds. Optional.
    public var retry: Int?

    /// Creates a new SSE event.
    ///
    /// - Parameters:
    ///   - data: The event data. Multi-line data is split across `data:` lines.
    ///   - event: The event type. Optional.
    ///   - id: A unique identifier for this event. Optional.
    ///   - retry: Reconnection time in milliseconds. Optional.
    @inlinable
    public init(
        data: String,
        event: String? = nil,
        id: String? = nil,
        retry: Int? = nil
    ) {
        self.data = data
        self.event = event
        self.id = id
        self.retry = retry
    }

    /// Formats this event as an SSE string per the specification.
    ///
    /// Each field appears on its own line. Multi-line `data` is split into
    /// multiple `data:` lines. The event is terminated by a blank line (`\n\n`).
    ///
    /// - Returns: A formatted SSE event string ending with a blank line.
    @inlinable
    public func formatted() -> String {
        var lines: [String] = []
        if let id {
            lines.append("id: \(id)")
        }
        if let event {
            lines.append("event: \(event)")
        }
        if let retry {
            lines.append("retry: \(retry)")
        }
        for line in data.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append("data: \(line)")
        }
        return lines.joined(separator: "\n") + "\n\n"
    }
}

// MARK: - Connection Extension

extension Connection {

    /// Returns a connection configured for Server-Sent Events streaming.
    ///
    /// This method configures the response with the correct `Content-Type`
    /// (`text/event-stream`), sets cache-control headers to prevent buffering,
    /// and establishes a streaming response body from an async sequence of
    /// ``SSEEvent`` values.
    ///
    /// The continuation-based API allows the caller to emit events from any
    /// async context (e.g., tasks, actors, or background operations). Call
    /// `continuation.finish()` when the stream is complete.
    ///
    /// - Parameter contentType: The `Content-Type` header value. Defaults to
    ///   `"text/event-stream; charset=utf-8"`. Override only if your client
    ///   requires a different charset.
    /// - Parameter body: A closure that receives an `AsyncStream<SSEEvent>.Continuation`
    ///   for emitting events. Call `continuation.yield(_:)` to send events and
    ///   `continuation.finish()` to terminate the stream.
    /// - Returns: A modified ``Connection`` with the SSE response configuration.
    ///
    /// ## Example
    ///
    /// ```swift
    /// return connection.sseEvent { continuation in
    ///     Task {
    ///         // Emit events
    ///         continuation.yield(SSEEvent(data: "hello", event: "message"))
    ///         try await Task.sleep(for: .seconds(1))
    ///         continuation.yield(SSEEvent(data: "world", event: "message"))
    ///
    ///         // Terminate the stream
    ///         continuation.finish()
    ///     }
    /// }
    /// ```
    ///
    /// ## HTTP Headers
    ///
    /// The following headers are set automatically:
    ///
    /// - `Content-Type: text/event-stream; charset=utf-8` (or custom value)
    /// - `Cache-Control: no-cache, no-transform` — disables proxy and browser caching
    /// - `X-Accel-Buffering: no` — disables nginx buffering (when behind nginx)
    ///
    /// These headers ensure events are delivered to the client immediately
    /// without intermediate buffering.
    @inlinable
    public func sseEvent(
        contentType: String = "text/event-stream; charset=utf-8",
        body: @escaping @Sendable (_ continuation: AsyncStream<SSEEvent>.Continuation) -> Void
    ) -> Connection {
        let (stream, continuation) = AsyncStream<SSEEvent>.makeStream()

        // Spawn the producer task
        Task {
            body(continuation)
        }

        var copy = self
        copy.response.headerFields[.contentType] = contentType
        copy.response.headerFields[.cacheControl] = "no-cache, no-transform"
        copy.response.headerFields[.init("X-Accel-Buffering")!] = "no"
        copy.responseBody = .stream(
            AsyncThrowingStream { continuation in
                var iterator = SSEEventSequence(base: stream).makeAsyncIterator()

                Task {
                    do {
                        while let data = try await iterator.next() {
                            continuation.yield(data)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        )
        return copy
    }
}
