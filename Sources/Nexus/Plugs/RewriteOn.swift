import Foundation
import HTTPTypes

/// The headers that ``rewriteOn(_:)`` can process.
public enum RewriteHeader: Sendable, Hashable {
    /// Rewrites the remote IP from `X-Forwarded-For`.
    case forwardedFor
    /// Rewrites the request scheme from `X-Forwarded-Proto`.
    case forwardedProto
    /// Rewrites the request host from `X-Forwarded-Host`.
    case forwardedHost
}

/// Rewrites connection fields from reverse proxy headers.
///
/// Applications behind reverse proxies (nginx, AWS ALB, Cloudflare) receive
/// requests where the scheme, host, and remote IP reflect the proxy, not
/// the client. This plug reads `X-Forwarded-*` headers and rewrites the
/// connection fields so downstream plugs see the real client values.
///
/// **Security:** Only use this plug if your application is actually behind
/// a trusted proxy. Without a proxy, clients can spoof these headers.
///
/// Place this as the **first** plug in the pipeline:
///
/// ```swift
/// let app = pipeline([
///     rewriteOn([.forwardedFor, .forwardedProto, .forwardedHost]),
///     sslRedirect(),
///     requestId(),
///     router,
/// ])
/// ```
///
/// - Parameter headers: The set of forwarded headers to process.
/// - Returns: A plug that rewrites connection fields from proxy headers.
public func rewriteOn(_ headers: Set<RewriteHeader>) -> Plug {
    { conn in
        var copy = conn

        if headers.contains(.forwardedProto),
           let name = HTTPField.Name("X-Forwarded-Proto"),
           let proto = conn.request.headerFields[name],
           !proto.isEmpty {
            copy.request.scheme = proto
        }

        if headers.contains(.forwardedHost),
           let name = HTTPField.Name("X-Forwarded-Host"),
           let host = conn.request.headerFields[name],
           !host.isEmpty {
            copy.request.authority = host
        }

        if headers.contains(.forwardedFor),
           let name = HTTPField.Name("X-Forwarded-For"),
           let forwarded = conn.request.headerFields[name],
           !forwarded.isEmpty {
            let firstIP = forwarded
                .split(separator: ",")
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            if let ip = firstIP, !ip.isEmpty {
                copy = copy.assign(key: Connection.remoteIPKey, value: ip)
            }
        }

        return copy
    }
}
