# Spec: Database Repo Injection Plug

**Status:** Proposed
**Date:** 2026-03-28
**Depends on:** Nexus core (complete), Connection assigns (complete)

---

## 1. Goal

Provide a conventional pattern for injecting a database repository (or any
shared service) into the Nexus pipeline so that route handlers access it from
`conn` rather than capturing an external `db` reference. This mirrors Phoenix's
pattern of putting the Ecto repo into `conn.assigns` via a plug, making the
data flow explicit and testable.

Today in DonutShop:
```swift
func donutRoutes(db: DB) -> [Route] {
    GET("/") { conn in
        let donuts = try await db.repo().all(Donut.self) // captured closure
        ...
    }
}
```

After:
```swift
GET("/") { conn in
    let donuts = try await conn.repo.all(Donut.self) // from the pipeline
    ...
}
```

---

## 2. Scope

### 2.1 Service Injection Plug Factory

Add a generic plug factory to Nexus core that injects any `Sendable` value
into `conn.assigns` under a given key:

```swift
// Sources/Nexus/Plugs/Assign.swift
public func assign<T: Sendable>(
    _ key: String,
    value: @escaping @Sendable () -> T
) -> Plug {
    { conn in
        conn.assign(key: key, value: value())
    }
}

public func assign<T: Sendable>(
    _ key: String,
    value: T
) -> Plug {
    { conn in
        conn.assign(key: key, value: value)
    }
}
```

### 2.2 Usage Pattern (Consumer Side)

DonutShop wires it into the pipeline:

```swift
let spectro = try SpectroClient(...)
let pipeline = pipeline([
    requestId(),
    assign("spectro", value: spectro),
    routerPlug,
])
```

Route handlers access it via a typed extension:

```swift
// In the consuming app (DonutShop)
extension Connection {
    var spectro: SpectroClient {
        assigns["spectro"] as! SpectroClient
    }
    func repo() -> GenericDatabaseRepo {
        spectro.repository()
    }
}
```

### 2.3 Documentation

Add a "Service Injection" section to the Nexus README showing the pattern with
a database example and a generic service example.

---

## 3. Acceptance Criteria

- [ ] `assign(_:value:)` plug factory exists in `Sources/Nexus/Plugs/Assign.swift`
- [ ] Both the static value and closure-based variants compile and work
- [ ] Value is accessible via `conn.assigns[key]` downstream in the pipeline
- [ ] The plug does not halt the connection
- [ ] The plug is `@Sendable` and works under Swift 6 strict concurrency
- [ ] Tests verify: value is present after plug runs, value persists through subsequent plugs, different types work (String, struct, actor reference)
- [ ] README includes a "Service Injection" example showing database repo pattern
- [ ] `swift test` passes with all new and existing tests

---

## 4. Non-goals

- No typed assign system in this spec (see spec 02-typed-assigns).
- No dependency injection container or service locator pattern.
- No automatic per-request scoping (e.g., transaction-per-request). That can be layered on later.
- No Spectro dependency in Nexus — the integration is consumer-side only.
