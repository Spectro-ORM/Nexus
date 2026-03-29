import HTTPTypes

/// Rewrites the HTTP method of a POST request when a `_method` form
/// parameter or query parameter is present.
///
/// HTML forms only support GET and POST. This plug lets server-rendered
/// forms submit PUT, PATCH, and DELETE requests by including a hidden
/// `_method` field:
///
/// ```html
/// <form method="post" action="/donuts/42">
///   <input type="hidden" name="_method" value="DELETE">
///   <button type="submit">Delete</button>
/// </form>
/// ```
///
/// Place this plug **after** body parsing is available and **before**
/// the router:
///
/// ```swift
/// let app = pipeline([
///     requestId(),
///     methodOverride(),
///     router,
/// ])
/// ```
///
/// Only POST requests are rewritten. Only `PUT`, `PATCH`, and `DELETE`
/// are valid override targets (case-insensitive). The form body parameter
/// takes precedence over the query string parameter.
///
/// - Returns: A plug that rewrites the request method when appropriate.
public func methodOverride() -> Plug {
    { conn in
        guard conn.request.method == .post else { return conn }

        let override = conn.formParams["_method"] ?? conn.queryParams["_method"]
        guard let override else { return conn }

        let method: HTTPRequest.Method? = switch override.uppercased() {
        case "PUT":    .put
        case "PATCH":  .patch
        case "DELETE": .delete
        default:       nil
        }

        guard let method else { return conn }

        var copy = conn
        copy.request.method = method
        return copy
    }
}
