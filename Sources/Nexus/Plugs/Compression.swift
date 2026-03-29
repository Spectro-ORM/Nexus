import Foundation
import HTTPTypes

// MARK: - Compression Plug

/// A plug that compresses response bodies based on the `Accept-Encoding` header.
///
/// Registered as a `beforeSend` hook so compression runs after the full
/// response body has been assembled by downstream plugs. Supported algorithms
/// are checked in priority order; the first one the client accepts is used.
///
/// Currently supports:
/// - `gzip` — standard gzip format (RFC 1952)
/// - `deflate` — zlib-wrapped DEFLATE (RFC 1950)
///
/// ```swift
/// let compression = Compression()
/// let app = pipeline([compression, router])
/// ```
///
/// Only responses with a buffered body that exceeds `minimumLength` bytes
/// are compressed. Streaming bodies are passed through unchanged.
public struct Compression: Sendable {

    /// Compression algorithms in priority order.
    public enum Algorithm: String, Sendable {
        /// Standard gzip encoding (RFC 1952).
        case gzip = "gzip"
        /// Zlib-wrapped DEFLATE (RFC 1950).
        case deflate = "deflate"
    }

    private let algorithms: [Algorithm]
    private let minimumLength: Int

    /// Creates a `Compression` plug.
    ///
    /// - Parameters:
    ///   - algorithms: Compression algorithms in preference order.
    ///     Defaults to `[.gzip, .deflate]`.
    ///   - minimumLength: Minimum response body size in bytes to trigger
    ///     compression. Defaults to 1024.
    public init(
        algorithms: [Algorithm] = [.gzip, .deflate],
        minimumLength: Int = 1024
    ) {
        self.algorithms = algorithms
        self.minimumLength = minimumLength
    }
}

extension Compression: ModulePlug {

    /// Registers a `beforeSend` hook that compresses the response body.
    ///
    /// - Parameter connection: The incoming connection.
    /// - Returns: The connection with a `beforeSend` compression hook registered.
    public func call(_ connection: Connection) async throws -> Connection {
        let algorithms = self.algorithms
        let minimumLength = self.minimumLength

        return connection.registerBeforeSend { conn in
            guard
                let acceptEncoding = conn.request.headerFields[.acceptEncoding],
                case .buffered(let data) = conn.responseBody,
                data.count >= minimumLength
            else {
                return conn
            }

            let encodingLower = acceptEncoding.lowercased()
            for algorithm in algorithms {
                guard encodingLower.contains(algorithm.rawValue) else { continue }
                guard let compressed = compress(data, using: algorithm) else { continue }

                var result = conn
                result.responseBody = .buffered(compressed)
                if let encodingField = HTTPField.Name("Content-Encoding") {
                    result.response.headerFields[encodingField] = algorithm.rawValue
                }
                // Remove Content-Length — it no longer reflects the compressed size.
                // The server adapter will re-compute it from the body.
                result.response.headerFields[.contentLength] = nil
                return result
            }
            return conn
        }
    }
}

// MARK: - Compression Helpers

/// Compresses `data` using the specified algorithm.
///
/// - Parameters:
///   - data: The data to compress.
///   - algorithm: The target compression algorithm.
/// - Returns: Compressed data, or `nil` if compression fails or the platform
///   lacks compression support.
private func compress(_ data: Data, using algorithm: Compression.Algorithm) -> Data? {
    #if canImport(Compression)
    switch algorithm {
    case .deflate:
        return (try? (data as NSData).compressed(using: .zlib)) as Data?

    case .gzip:
        // NSData.compressed(using: .zlib) produces zlib-wrapped DEFLATE.
        // Strip the 2-byte zlib header and 4-byte Adler-32 trailer to obtain
        // raw DEFLATE, then wrap it in the standard 10-byte gzip header and
        // an 8-byte gzip trailer (CRC-32 + uncompressed size).
        guard let zlibData = (try? (data as NSData).compressed(using: .zlib)) as Data?,
              zlibData.count > 6 else {
            return nil
        }
        let rawDeflate = zlibData.subdata(in: 2..<(zlibData.count - 4))
        return makeGzip(rawDeflate: rawDeflate, original: data)
    }
    #else
    // NSData.compressed(using:) is Apple-only. On Linux, compression is a
    // no-op until a cross-platform zlib binding is added.
    return nil
    #endif
}

/// Wraps raw DEFLATE data in a gzip container (RFC 1952).
private func makeGzip(rawDeflate: Data, original: Data) -> Data {
    let crc = crc32(original)
    let size = UInt32(original.count & 0xFFFF_FFFF)

    var result = Data(capacity: 10 + rawDeflate.count + 8)
    // Gzip header: magic (1F 8B), deflate method (08), no flags, zero mtime,
    // default XFL, unknown OS (FF).
    result.append(contentsOf: [0x1F, 0x8B, 0x08, 0x00,
                                0x00, 0x00, 0x00, 0x00,
                                0x00, 0xFF])
    result.append(rawDeflate)
    // CRC-32 of original data (little-endian).
    result.append(contentsOf: littleEndianBytes(crc))
    // Uncompressed size mod 2^32 (little-endian).
    result.append(contentsOf: littleEndianBytes(size))
    return result
}

/// Computes the CRC-32 checksum of `data` using the standard polynomial.
private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
        }
    }
    return crc ^ 0xFFFF_FFFF
}

/// Returns the four little-endian bytes of a `UInt32`.
private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    [
        UInt8(value & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 24) & 0xFF),
    ]
}
