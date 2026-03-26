import Foundation

/// A lightweight wrapper around parsed JSON for dynamic field access.
///
/// Use ``Connection/jsonBody()`` to parse the request body into a
/// `JSONValue`, then access fields with typed accessors:
///
/// ```swift
/// POST("/webhook") { conn in
///     let json = try conn.jsonBody()
///     let event = try json.string("event")
///     let count = try json.int("count")
///     // ...
/// }
/// ```
///
/// For complex or nested request bodies, prefer ``Connection/decode(as:decoder:)``
/// with a `Decodable` struct instead.
// @unchecked Sendable: raw holds only Foundation JSON types
// (String, NSNumber, NSArray, NSDictionary, NSNull) which are
// immutable/thread-safe. JSONSerialization guarantees this.
public struct JSONValue: @unchecked Sendable {

    private let raw: Any

    init(_ raw: Any) {
        self.raw = raw
    }

    /// Accesses a nested value by key.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: A `JSONValue` wrapping the nested value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the root is not
    ///   an object or the key does not exist.
    public subscript(key: String) -> JSONValue {
        get throws {
            guard let dict = raw as? [String: Any] else {
                throw NexusHTTPError(.badRequest, message: "Expected JSON object")
            }
            guard let value = dict[key] else {
                throw NexusHTTPError(.badRequest, message: "Missing key: \(key)")
            }
            return JSONValue(value)
        }
    }

    /// Returns the value as a `String`.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: The string value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the key is missing
    ///   or the value is not a string.
    public func string(_ key: String) throws -> String {
        let child = try self[key]
        guard let value = child.raw as? String else {
            throw NexusHTTPError(.badRequest, message: "Expected string for key: \(key)")
        }
        return value
    }

    /// Returns the value as an `Int`.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: The integer value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the key is missing
    ///   or the value is not a number.
    public func int(_ key: String) throws -> Int {
        let child = try self[key]
        if let value = child.raw as? Int {
            return value
        }
        if let value = child.raw as? Double {
            return Int(value)
        }
        throw NexusHTTPError(.badRequest, message: "Expected integer for key: \(key)")
    }

    /// Returns the value as a `Double`.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: The double value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the key is missing
    ///   or the value is not a number.
    public func double(_ key: String) throws -> Double {
        let child = try self[key]
        if let value = child.raw as? Double {
            return value
        }
        if let value = child.raw as? Int {
            return Double(value)
        }
        throw NexusHTTPError(.badRequest, message: "Expected number for key: \(key)")
    }

    /// Returns the value as a `Bool`.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: The boolean value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the key is missing
    ///   or the value is not a boolean.
    public func bool(_ key: String) throws -> Bool {
        let child = try self[key]
        guard let value = child.raw as? Bool else {
            throw NexusHTTPError(.badRequest, message: "Expected boolean for key: \(key)")
        }
        return value
    }

    /// Returns the value as an array of `JSONValue`.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: An array of `JSONValue` elements.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the key is missing
    ///   or the value is not an array.
    public func array(_ key: String) throws -> [JSONValue] {
        let child = try self[key]
        guard let value = child.raw as? [Any] else {
            throw NexusHTTPError(.badRequest, message: "Expected array for key: \(key)")
        }
        return value.map { JSONValue($0) }
    }

    /// Returns the value as a nested `JSONValue` object.
    ///
    /// - Parameter key: The JSON object key.
    /// - Returns: A `JSONValue` wrapping the nested object.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the key is missing
    ///   or the value is not an object.
    public func object(_ key: String) throws -> JSONValue {
        let child = try self[key]
        guard child.raw is [String: Any] else {
            throw NexusHTTPError(.badRequest, message: "Expected object for key: \(key)")
        }
        return child
    }

    /// Returns the raw string value when this `JSONValue` is a string leaf.
    ///
    /// Useful when iterating arrays: `for item in try json.array("items") { try item.stringValue() }`
    ///
    /// - Returns: The string value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if this is not a string.
    public func stringValue() throws -> String {
        guard let value = raw as? String else {
            throw NexusHTTPError(.badRequest, message: "Expected string value")
        }
        return value
    }

    /// Returns the raw integer value when this `JSONValue` is a number leaf.
    ///
    /// - Returns: The integer value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if this is not a number.
    public func intValue() throws -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? Double { return Int(value) }
        throw NexusHTTPError(.badRequest, message: "Expected integer value")
    }

    /// Returns the raw double value when this `JSONValue` is a number leaf.
    ///
    /// - Returns: The double value.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if this is not a number.
    public func doubleValue() throws -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        throw NexusHTTPError(.badRequest, message: "Expected number value")
    }
}

// MARK: - Connection Integration

extension Connection {

    /// Parses the buffered request body as JSON and returns a ``JSONValue``
    /// for dynamic field access.
    ///
    /// Use this for simple request bodies where defining a `Decodable` struct
    /// would be overkill. For complex or nested structures, prefer
    /// ``decode(as:decoder:)``.
    ///
    /// ```swift
    /// POST("/webhook") { conn in
    ///     let json = try conn.jsonBody()
    ///     let event = try json.string("event")
    ///     return try conn.json(value: ["received": event])
    /// }
    /// ```
    ///
    /// - Returns: A `JSONValue` wrapping the parsed JSON.
    /// - Throws: ``NexusHTTPError`` with `.badRequest` if the body is empty
    ///   or contains invalid JSON.
    public func jsonBody() throws -> JSONValue {
        guard case .buffered(let data) = requestBody else {
            throw NexusHTTPError(.badRequest, message: "Missing request body")
        }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else {
            throw NexusHTTPError(.badRequest, message: "Invalid JSON")
        }
        return JSONValue(parsed)
    }
}
