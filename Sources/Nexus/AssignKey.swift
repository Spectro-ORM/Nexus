/// A type-safe key for values stored in ``Connection/assigns``.
///
/// Define an `AssignKey` conformance for each distinct piece of data that
/// plugs pass through the pipeline. The associated `Value` type eliminates
/// the need for manual casting:
///
/// ```swift
/// enum SpectroKey: AssignKey {
///     typealias Value = SpectroClient
/// }
///
/// // Write
/// conn = conn.assign(SpectroKey.self, value: spectro)
///
/// // Read — returns SpectroClient?, no cast needed
/// let spectro = conn[SpectroKey.self]
/// ```
///
/// The default value is `nil`. Override ``defaultValue`` to provide a
/// fallback when the key has not been explicitly set.
public protocol AssignKey {
    /// The type of value stored under this key.
    associatedtype Value: Sendable

    /// The value returned when the key has not been explicitly set.
    ///
    /// Defaults to `nil`.
    static var defaultValue: Value? { get }
}

extension AssignKey {
    /// Returns `nil` by default.
    public static var defaultValue: Value? { nil }
}
