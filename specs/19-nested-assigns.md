# Spec 19: Nested Assigns

## Summary

Add support for nested path access in connection assigns, allowing structured data storage like Elixir's `assign/3` with nested paths.

## Motivation

Current assigns are flat:
```swift
// Current -只能 flat keys
conn = conn.assign("user_name", value: "John")
conn = conn.assign("user_age", value: 30)
```

Elixir supports nested paths:
```elixir
assign(conn, :user, %{name: "John", age: 30})
assign(conn, [:user, :profile], %{bio: "Developer"})
# Access via: conn.assigns.user.name
```

Need to support nested data structures without flattening keys.

## Design

Two approaches:

### Approach 1: Dot-notation paths
```swift
// Set nested values
conn = conn.assign("user.name", value: "John")
conn = conn.assign("user.profile.bio", value: "Developer")

// Get nested values
let name = conn["user.name"] as? String
```

### Approach 2: Array paths (closer to Elixir)
```swift
// Set nested values
conn = conn.assign(\.user.name, value: "John")
conn = conn.assign(["user", "profile", "bio"], value: "Developer")

// Get nested values
let name = conn[["user", "name"]] as? String
````

### Approach 3: KeyPath-based
```swift
// Type-safe nested keys
enum AssignKey: String {
    case user = "user"
    case profile = "profile"
    case bio = "bio"
}

// Nested access
conn = conn.assign(\.user.profile.bio, value: "Developer")
```

## Acceptance Criteria

### Nested Set Operations
- [ ] `assign(_:_:value:)` supports dot-notation paths (e.g., `"user.name"`)
- [ ] `assign(_:_:value:)` supports array paths (e.g., `["user", "name"]`)
- [ ] Creating intermediate dictionaries for missing path segments
- [ ] Overwriting existing nested values preserves other branches

### Nested Get Operations
- [ ] Subscript `conn["path.key"]` retrieves nested values
- [ ] Subscript `conn["path.key"]` returns `nil` for missing paths
- [ ] Type casting works on retrieved nested values

### Edge Cases
- [ ] Empty path returns root assigns
- [ ] Single key path works same as flat key
- [ ] Path with nil intermediate values returns nil
- [ ] Path traversal through non-dictionary values returns nil

### Integration
- [ ] Nested assigns work with `assigns` property
- [ ] Nested assigns work with pipeline composition
- [ ] Nested assigns work with `halt()`
- [ ] Nested assigns work with AssignKey protocol

### Backward Compatibility
- [ ] Flat key access continues to work
- [ ] No breaking changes to `assign(key:value:)`
- [ ] New methods are additive

## Examples

### Basic Nested Assigns
```swift
// Using dot notation
conn = conn.assign("user.name", value: "John Doe")
conn = conn.assign("user.email", value: "john@example.com")
conn = conn.assign("user.settings.theme", value: "dark")

// Using array paths
conn = conn.assign(["product", "id"], value: 123)
conn = conn.assign(["product", "price", "amount"], value: 99.99)
conn = conn.assign(["product", "price", "currency"], value: "USD")
```

### Reading Nested Values
```swift
// Get nested values
let name = conn["user.name"] as? String  // "John Doe"
let theme = conn["user.settings.theme"] as? String  // "dark"

// Safely access nested values
if let productPrice = conn["product.price.amount"] as? Double {
    print("Price: \(productPrice)")
}
```

### Complex Structures
```swift
// Assign nested objects
let user: [String: AnySendable] = [
    "name": "John",
    "roles": ["admin", "user"],
    "profile": [
        "bio": "Developer",
        "avatar": "https://example.com/avatar.jpg"
    ]
]
conn = conn.assign("user", value: user)

// Access nested array
let roles = conn["user.roles"] as? [String]  // ["admin", "user"]
```

### With AssignKey
```swift
// Combine with typed keys
struct UserKey: AssignKey {
    static let defaultValue: [String: AnySendable]? = nil
}

// Set nested value
conn = conn.assign(UserKey.keyPath + "profile.bio", value: "Developer")

// Get nested value
let bio = conn[UserKey.keyPath + "profile.bio"] as? String
```

## Implementation Notes

- Add overloads to `assign(_:_:value:)` in `Connection+Assign.swift`
- Subscript `conn[_:]` in `Connection.swift` handles path parsing
- Path separator: `.` (dot) for simplicity
- Handle edge cases: empty paths, single keys, nil intermediates
- Consider performance: path parsing on each access
