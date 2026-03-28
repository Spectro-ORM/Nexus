import Foundation

/// A message exchanged over a WebSocket connection.
///
/// Maps to the standard WebSocket frame types. Nexus handlers receive and
/// send these values instead of working with raw frames.
public enum WSMessage: Sendable, Equatable {
    /// A UTF-8 text message.
    case text(String)
    /// A binary data message.
    case binary(Data)
    /// A ping control frame.
    case ping
    /// A pong control frame.
    case pong
    /// A close control frame with an optional status code and reason.
    case close(code: UInt16?, reason: String?)

    public static func == (lhs: WSMessage, rhs: WSMessage) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.binary(let a), .binary(let b)): return a == b
        case (.ping, .ping): return true
        case (.pong, .pong): return true
        case (.close(let c1, let r1), .close(let c2, let r2)): return c1 == c2 && r1 == r2
        default: return false
        }
    }
}
