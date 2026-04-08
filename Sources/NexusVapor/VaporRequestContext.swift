import Vapor
import NIOCore

/// A request context for Vapor that captures the remote address from the
/// underlying NIO channel.
///
/// ``VaporRequestContext`` serves as a bridge between Vapor's request model
/// and Nexus's connection model, capturing request metadata that isn't
/// directly available on Vapor's `Request` object.
///
/// ## Overview
///
/// Unlike Hummingbird, which has a dedicated `RequestContext` protocol for
/// passing request-scoped data, Vapor stores most request data directly on
/// the `Request` object itself. ``VaporRequestContext`` exists primarily to
/// capture the remote address information from the NIO `Channel`, which is
/// used to populate ``Connection/remoteIP``.
///
/// ## Usage
///
/// ``NexusVaporAdapter`` uses this context internally during request
/// translation. The context is created from the incoming Vapor request,
/// and the remote address is extracted and stored in the connection's
/// assigns.
///
/// ## Remote Address Availability
///
/// The ``remoteAddress`` may be `nil` in certain situations:
///
/// - Testing environments that don't use real network connections
/// - Server configurations where remote address information is not available
/// - Requests forwarded through proxies that don't preserve the original IP
///
/// When the remote address is unavailable, ``Connection/remoteIP`` will
/// be `nil`, and plugs should handle this gracefully.
///
/// ## Related Types
///
/// - ``NexusVaporAdapter`` - Uses this context during request translation
/// - ``Connection/remoteIP`` - Populated from this context's remote address
/// - ``Connection`` - The connection type that receives the remote IP
public struct VaporRequestContext {

    /// The underlying Vapor request.
    ///
    /// Vapor stores all request data (headers, query parameters, body, URI, etc.)
    /// directly on this object, making it the primary source of request
    /// information in the Vapor ecosystem.
    ///
    /// ## Accessing Request Data
    ///
    /// The `request` object provides access to:
    /// - HTTP headers via `request.headers`
    /// - Query parameters via `request.query`
    /// - Request body via `request.body`
    /// - URI components via `request.url`
    /// - Method via `request.method`
    /// - And other request metadata
    public let request: Request

    /// The remote socket address of the connected client, if available.
    ///
    /// This address is extracted from the NIO `Channel` associated with
    /// the request. It represents the client's IP address and port as
    /// seen by the server.
    ///
    /// ## Availability
    ///
    /// May be `nil` in:
    /// - Testing environments without real network connections
    /// - Server configurations that don't expose remote address
    /// - Proxy setups that don't preserve the original client IP
    ///
    /// ## Usage
    ///
    /// When available, this address is converted to a string and stored
    /// in ``Connection/remoteIP`` using ``Connection/remoteIPKey``.
    ///
    /// ## Related Types
    ///
    /// - ``Connection/remoteIP`` - The connection property populated from this
    /// - ``Connection/remoteIPKey`` - The assign key used to store the remote IP
    public let remoteAddress: SocketAddress?

    /// Creates a context from a Vapor request.
    ///
    /// This initializer extracts the remote address from the request's
    /// underlying NIO channel. The remote address is automatically
    /// populated from `request.remoteAddress`.
    ///
    /// - Parameter request: The incoming Vapor request. The remote address
    ///   is extracted from the request's underlying NIO channel.
    ///
    /// - Returns: A new ``VaporRequestContext`` containing the request and
    ///   its remote address (if available).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Inside a Vapor request handler
    /// let context = VaporRequestContext(request: request)
    ///
    /// if let address = context.remoteAddress {
    ///     print("Client IP: \(address.ipAddress ?? "unknown")")
    /// }
    /// ```
    ///
    /// ## Note
    ///
    /// This initializer is typically called by ``NexusVaporAdapter`` during
    /// request translation. Most users don't need to create contexts manually.
    public init(request: Request) {
        self.request = request
        self.remoteAddress = request.remoteAddress
    }
}
