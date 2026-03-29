// MARK: - PlugPipeline Result Builder

/// A result builder for composing an ordered list of ``Plug`` closures into
/// a pipeline using SwiftUI-style declarative syntax.
///
/// Use ``buildPipeline(_:)`` to create a pipeline with this builder:
///
/// ```swift
/// let app = buildPipeline {
///     requestId()
///     requestLogger()
///     csrf()
///     router
/// }
/// ```
///
/// ``ModulePlug`` and ``ConfigurablePlug`` conforming instances are
/// automatically converted to ``Plug`` via their `asPlug()` method:
///
/// ```swift
/// buildPipeline {
///     SecurityHeaders(includeHSTS: true)  // ModulePlug
///     router                              // Plug (callAsFunction)
/// }
/// ```
///
/// ## Conditional Plugs
///
/// ```swift
/// buildPipeline {
///     if isDebug {
///         debugger()
///     }
///     router
/// }
/// ```
@resultBuilder
public struct PlugPipeline {

    /// Composes the individual plug expressions into an ordered array.
    public static func buildBlock(_ components: [Plug]...) -> [Plug] {
        components.flatMap { $0 }
    }

    /// Converts a ``Plug`` expression into a single-element array.
    public static func buildExpression(_ plug: @escaping Plug) -> [Plug] {
        [plug]
    }

    /// Converts a ``ModulePlug`` expression into a ``Plug`` array.
    public static func buildExpression(_ module: some ModulePlug) -> [Plug] {
        [module.asPlug()]
    }

    /// Converts a ``ConfigurablePlug`` expression into a ``Plug`` array.
    public static func buildExpression(_ configurable: some ConfigurablePlug) -> [Plug] {
        [configurable.asPlug()]
    }

    /// Supports optional plugs (`if condition { plug }`).
    public static func buildOptional(_ component: [Plug]?) -> [Plug] {
        component ?? []
    }

    /// Supports if–else plug selections (true branch).
    public static func buildEither(first component: [Plug]) -> [Plug] {
        component
    }

    /// Supports if–else plug selections (false branch).
    public static func buildEither(second component: [Plug]) -> [Plug] {
        component
    }

    /// Supports `for` loops over plug collections.
    public static func buildArray(_ components: [[Plug]]) -> [Plug] {
        components.flatMap { $0 }
    }
}

// MARK: - buildPipeline

/// Composes an ordered list of plugs into a single pipeline using the
/// ``PlugPipeline`` DSL.
///
/// ```swift
/// let app = buildPipeline {
///     requestId()
///     requestLogger()
///     router
/// }
/// ```
///
/// This is syntactic sugar over `pipeline([ ... ])`. Both are equivalent;
/// use whichever style fits your codebase.
///
/// - Parameter builder: A ``PlugPipeline`` builder closure.
/// - Returns: A single ``Plug`` that runs all declared plugs in order,
///   stopping early if any plug halts the connection.
public func buildPipeline(@PlugPipeline _ builder: () -> [Plug]) -> Plug {
    pipeline(builder())
}
