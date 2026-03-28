# Spec: Typed Assigns for Connection

**Status:** Proposed
**Date:** 2026-03-28
**Depends on:** Nexus core (complete), Connection assigns (complete)

---

## 1. Goal

Replace the stringly-typed `conn.assigns["key"] as? T` pattern with a
type-safe key-based system. Today, every access to assigns requires a string
key and an unsafe cast:

```swift
let requestId = conn.assigns["request_id"] as? String ?? "unknown"
```

This is error-prone (typos, wrong types, missing keys are all runtime errors).
The goal is a compile-time-safe pattern:

```swift
let requestId = conn[.requestId]  // String, never nil if plug ran
```

---

## 2. Scope

### 2.1 AssignKey Protocol

```swift
// Sources/Nexus/AssignKey.swift
public protocol AssignKey {
    associatedtype Value: Sendable
    static var defaultValue: Value? { get }
}

extension AssignKey {
    public static var defaultValue: Value? { nil }
}
```

### 2.2 Connection Subscript

```swift
// Sources/Nexus/Connection+TypedAssigns.swift
extension Connection {
    public subscript<K: AssignKey>(key: K.Type) -> K.Value? {
        get { assigns[String(describing: key)] as? K.Value ?? K.defaultValue }
    }

    public func assign<K: AssignKey>(_ key: K.Type, value: K.Value) -> Connection {
        assign(key: String(describing: key), value: value)
    }
}
```

### 2.3 Built-in Keys for Existing Plugs

Define keys for the assigns that Nexus plugs already set:

```swift
// Sources/Nexus/AssignKeys.swift
public enum RequestIdKey: AssignKey {
    public typealias Value = String
}

public enum SessionKey: AssignKey {
    public typealias Value = [String: String]
}

public enum RemoteIPKey: AssignKey {
    public typealias Value = String
}
```

Update existing plugs (`requestId()`, `Session`, etc.) to use the typed API
internally while keeping backward compatibility with the string-based API.

### 2.4 Convenience Accessors

For the most common built-in keys, add computed properties:

```swift
extension Connection {
    public var requestId: String? { self[RequestIdKey.self] }
    public var session: [String: String]? { self[SessionKey.self] }
    public var remoteIP: String? { self[RemoteIPKey.self] }
}
```

### 2.5 Backward Compatibility

The existing `conn.assigns["key"]` dictionary remains accessible. Typed assigns
write to the same underlying dictionary using the key type's name as the string
key. Both APIs can coexist — consumers migrate at their own pace.

---

## 3. Acceptance Criteria

- [ ] `AssignKey` protocol exists with `associatedtype Value: Sendable`
- [ ] `Connection` subscript allows `conn[KeyType.self]` get access
- [ ] `Connection.assign(_:value:)` method allows typed assignment returning new `Connection`
- [ ] `RequestIdKey`, `SessionKey`, `RemoteIPKey` are defined for built-in plugs
- [ ] `conn.requestId`, `conn.session`, `conn.remoteIP` convenience accessors work
- [ ] `requestId()` plug writes via the typed API
- [ ] Typed and string-based APIs read from the same underlying dictionary
- [ ] Existing tests continue to pass (no breaking changes)
- [ ] New tests verify: typed write + typed read, typed write + string read, string write + typed read
- [ ] All types compile under Swift 6 strict concurrency
- [ ] `AssignKey` values are constrained to `Sendable`
- [ ] Consumer-defined keys work (test with a custom key type)

---

## 4. Verification

```swift
// Consumer defines a key
enum SpectroKey: AssignKey {
    typealias Value = SpectroClient
}

// Plug sets it
func dbPlug(spectro: SpectroClient) -> Plug {
    { conn in conn.assign(SpectroKey.self, value: spectro) }
}

// Handler reads it
GET("/") { conn in
    let spectro = conn[SpectroKey.self]! // SpectroClient, typed
    ...
}
```

---

## 5. Non-goals

- No `@propertyWrapper`-based API (too much complexity for the benefit).
- No required/non-optional typed assigns with compile-time enforcement (would require phantom types on Connection, breaks the value-type simplicity).
- No deprecation of string-based assigns in this spec.
