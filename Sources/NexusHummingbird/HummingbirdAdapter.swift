import Foundation
import Hummingbird
import HummingbirdCore
import NIOCore
import Nexus

/// Bridges a Nexus plug pipeline to Hummingbird's request handling layer.
///
/// `NexusHummingbirdAdapter` converts an incoming `Request` from Hummingbird
/// into a Nexus ``Connection``, runs it through a ``Plug`` pipeline, and
/// converts the resulting ``Connection`` back into a Hummingbird `Response`.
///
/// The adapter implements Hummingbird's `HTTPResponder` protocol, making it
/// directly usable as the responder for an `Application`:
///
/// ```swift
/// let adapter = NexusHummingbirdAdapter(plug: pipeline([
///     logger,
///     authPlug,
///     router.handle,
/// ]))
/// let app = Application(responder: adapter)
/// try await app.runService()
/// ```
///
/// ## Error Handling (ADR-004)
///
/// - **Halted connections** (HTTP-level rejections): The adapter reads
///   `connection.response` and `connection.responseBody` and returns them
///   as a Hummingbird `Response`.
/// - **Thrown errors** (infrastructure failures): The adapter catches the
///   error and returns a generic `500 Internal Server Error`.
public struct NexusHummingbirdAdapter: Sendable {

    private let plug: Plug
    private let maxRequestBodySize: Int

    /// Creates an adapter that wraps the given plug pipeline.
    ///
    /// - Parameters:
    ///   - plug: The root plug that handles every incoming request.
    ///   - maxRequestBodySize: Maximum number of bytes to buffer from the
    ///     request body. Defaults to 4 MB (4,194,304 bytes).
    public init(plug: @escaping Plug, maxRequestBodySize: Int = 4_194_304) {
        self.plug = plug
        self.maxRequestBodySize = maxRequestBodySize
    }
}

// MARK: - HTTPResponder

extension NexusHummingbirdAdapter: HTTPResponder {

    public typealias Context = BasicRequestContext

    /// Converts a Hummingbird request into a Nexus ``Connection``, runs it
    /// through the plug pipeline, and converts the result back into a
    /// Hummingbird response.
    ///
    /// - Parameters:
    ///   - request: The incoming Hummingbird request.
    ///   - context: The Hummingbird request context.
    /// - Returns: A Hummingbird `Response` built from the pipeline result.
    /// - Throws: Only if body collection exceeds ``maxRequestBodySize``.
    ///   Pipeline errors are caught and converted to 500 responses per ADR-004.
    public func respond(
        to request: Request,
        context: BasicRequestContext
    ) async throws -> Response {
        // 1. Convert Hummingbird Request → Nexus Connection
        let buffer = try await request.body.collect(upTo: maxRequestBodySize)
        let nexusRequestBody: Nexus.RequestBody = buffer.readableBytes > 0
            ? .buffered(Data(buffer.readableBytesView))
            : .empty
        let connection = Connection(
            request: request.head,
            requestBody: nexusRequestBody
        )

        // 2. Run the plug pipeline, catching infrastructure errors (ADR-004)
        let result: Connection
        do {
            result = try await plug(connection)
        } catch {
            return Response(status: .internalServerError)
        }

        // 3. Run lifecycle hooks before serializing the response (ADR-006)
        let finalResult = result.runBeforeSend()

        // 4. Convert Nexus Connection → Hummingbird Response
        let responseBody: HummingbirdCore.ResponseBody
        switch finalResult.responseBody {
        case .empty:
            responseBody = HummingbirdCore.ResponseBody()
        case .buffered(let data):
            responseBody = HummingbirdCore.ResponseBody(
                byteBuffer: ByteBuffer(bytes: data)
            )
        case .stream(let stream):
            responseBody = HummingbirdCore.ResponseBody(
                asyncSequence: stream.map { ByteBuffer(bytes: $0) }
            )
        }

        return Response(
            status: finalResult.response.status,
            headers: finalResult.response.headerFields,
            body: responseBody
        )
    }
}
