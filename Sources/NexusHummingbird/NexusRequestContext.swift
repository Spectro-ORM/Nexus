import Hummingbird
import NIOCore

/// A request context that captures the remote address from the underlying
/// NIO channel.
///
/// ``NexusHummingbirdAdapter`` uses this context to populate the
/// ``Nexus/Connection/remoteIP`` property on each incoming connection.
public struct NexusRequestContext: RequestContext {

    /// Core Hummingbird request context storage.
    public var coreContext: CoreRequestContextStorage

    /// The remote socket address of the connected client, if available.
    ///
    /// Extracted from the NIO `Channel` during context initialization.
    /// May be `nil` in testing environments (e.g. when using
    /// `NIOAsyncTestingChannel`).
    public let remoteAddress: SocketAddress?

    /// Creates a context from the Hummingbird application source.
    ///
    /// - Parameter source: The application-level context source carrying
    ///   the NIO channel and logger.
    public init(source: ApplicationRequestContextSource) {
        self.coreContext = .init(source: source)
        self.remoteAddress = source.channel.remoteAddress
    }
}
