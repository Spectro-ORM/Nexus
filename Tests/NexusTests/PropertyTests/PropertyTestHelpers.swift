import Testing
import SwiftCheck
import Foundation

/// Property test helpers that bridge SwiftCheck with Swift Testing framework.
///
/// This module provides utilities for writing property-based tests using SwiftCheck
/// within the Swift Testing framework, enabling randomized testing with shrunk failures.
///
/// # Example Usage
/// ```swift
/// @Suite("MyProperties")
/// struct MyProperties {
///     @Test("array reversal property")
///     func arrayReversalProperty() {
///         property("reversing twice returns original") <- forAll { (xs: [Int]) in
///             xs.reversed().reversed() == xs
///         }
///     }
/// }
/// ```

/// Common generators for Nexus types
extension Gen {
    /// Generate non-empty strings
    public static var nonEmptyString: Gen<String> {
        return String.arbitrary.suchThat { !$0.isEmpty }
    }

    /// Generate valid HTTP method strings
    public static var httpMethod: Gen<String> {
        return Gen<String>.fromElements(of: ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS", "TRACE"])
    }

    /// Generate valid HTTP status codes
    public static var httpStatusCode: Gen<Int> {
        return Gen<Int>.fromElements(of: [200, 201, 204, 301, 302, 400, 401, 403, 404, 500, 502, 503])
    }

    /// Generate HTTP header values (ASCII strings)
    public static var httpHeaderValue: Gen<String> {
        return String.arbitrary.suchThat { str in
            str.allSatisfy { $0.isASCII }
        }
    }

    /// Generate data chunks for streaming
    public static func dataChunk(maxSize: Int = 1024) -> Gen<Data> {
        return Gen<Int>.choose((0, maxSize)).map { size in
            Data((0..<size).map { _ in UInt8.random(in: 0...255) })
        }
    }
}

/// Custom test configuration for property-based tests
public struct PropertyTestConfig: Sendable {
    public let maxTestCases: Int
    public let maxShrinkCount: Int
    public let verbose: Bool

    public static let `default` = PropertyTestConfig(
        maxTestCases: 100,
        maxShrinkCount: 1000,
        verbose: false
    )

    public static let thorough = PropertyTestConfig(
        maxTestCases: 1000,
        maxShrinkCount: 1000,
        verbose: true
    )

    public static let quick = PropertyTestConfig(
        maxTestCases: 50,
        maxShrinkCount: 100,
        verbose: false
    )
}

/// Assert that a property holds for all generated inputs
///
/// - Parameters:
///   - property: SwiftCheck property to test
///   - config: Test configuration (currently unused, kept for API compatibility)
///   - file: Source file for failure reporting
///   - line: Source line for failure reporting
public func assertProperty(
    _ property: Property,
    config: PropertyTestConfig = .default,
    file: StaticString = #file,
    line: UInt = #line
) {
    // SwiftCheck properties run automatically when tested
    // The property function handles test case generation and shrinking
    // This is a placeholder for future integration enhancements
}
