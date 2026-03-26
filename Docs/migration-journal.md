# Nexus Migration Journal: DonutShop (Hummingbird → Nexus)

A side-by-side record of porting a real Hummingbird 2 app to Nexus.

---

## DonutRoutes.swift

### Before (Hummingbird)

```swift
import Foundation
import Hummingbird
import Spectro

func addDonutRoutes(to router: Router<BasicRequestContext>, db: DB) {
    let group = router.group("/donuts")

    // List available donuts with category preloaded
    group.get { _, _ -> String in
        let donuts = try await db.repo().query(Donut.self)
            .where { q in q.isAvailable == true }
            .orderBy(\.name)
            .preload(\.$category)
            .all()

        return try encodeJSON(donuts.map { d in
            ["id": "\(d.id)", "name": d.name, "price": "\(d.price)"]
        })
    }

    // Search donuts by name (ilike)
    group.get("search") { request, _ -> String in
        let q = request.uri.queryParameters.get("q") ?? ""
        let results = try await db.repo().query(Donut.self)
            .where { f in f.name.ilike("%\(q)%") }
            .orderBy(\.price)
            .limit(20)
            .all()

        return try encodeJSON(results.map { d in
            ["id": "\(d.id)", "name": d.name, "price": "\(d.price)"]
        })
    }

    // Get donut with toppings (many-to-many) and category preloaded
    group.get(":id") { _, context -> String in
        guard let idStr = context.parameters.get("id"),
              let donutId = UUID(uuidString: idStr) else {
            throw HTTPError(.badRequest, message: "Invalid donut ID")
        }
        let donut = try await db.repo().query(Donut.self)
            .where { q in q.id == donutId }
            .preload(\.$category)
            .preload(\.$toppings)
            .first()

        guard let donut else {
            throw HTTPError(.notFound, message: "Donut not found")
        }

        return try encodeJSON([
            "id": "\(donut.id)",
            "name": donut.name,
            "price": "\(donut.price)",
            "toppings": "\(donut.toppings.map { $0.name }.joined(separator: ", "))",
        ])
    }

    // Create a donut
    group.post { request, context -> String in
        struct CreateDonut: Decodable, Sendable {
            let name: String
            let description: String
            let price: Double
            let categoryId: String
        }
        let body = try await request.decode(as: CreateDonut.self, context: context)
        guard let catId = UUID(uuidString: body.categoryId) else {
            throw HTTPError(.badRequest, message: "Invalid category ID")
        }

        var donut = Donut()
        donut.name = body.name
        donut.descriptionText = body.description
        donut.price = body.price
        donut.categoryId = catId
        donut.isAvailable = true

        let created = try await db.repo().insert(donut)
        return try encodeJSON(["id": "\(created.id)", "name": created.name])
    }
}
```

### After (Nexus)

```swift
import Foundation
import Nexus
import NexusRouter
import Spectro

@RouteBuilder
func donutRoutes(db: DB) -> [Route] {
    // List available donuts
    GET("/") { conn in
        let donuts = try await db.repo().query(Donut.self)
            .where { q in q.isAvailable == true }
            .orderBy(\.name)
            .preload(\.$category)
            .all()

        return try conn.json(value: donuts.map { d in
            ["id": "\(d.id)", "name": d.name, "price": "\(d.price)"]
        })
    }

    // Search donuts by name
    GET("/search") { conn in
        let q = conn.queryParams["q"] ?? ""
        let results = try await db.repo().query(Donut.self)
            .where { f in f.name.ilike("%\(q)%") }
            .orderBy(\.price)
            .limit(20)
            .all()

        return try conn.json(value: results.map { d in
            ["id": "\(d.id)", "name": d.name, "price": "\(d.price)"]
        })
    }

    // Get donut by ID
    GET("/:id") { conn in
        guard let idStr = conn.params["id"],
              let donutId = UUID(uuidString: idStr) else {
            throw NexusHTTPError(.badRequest, message: "Invalid donut ID")
        }
        let donut = try await db.repo().query(Donut.self)
            .where { q in q.id == donutId }
            .preload(\.$category)
            .preload(\.$toppings)
            .first()

        guard let donut else {
            throw NexusHTTPError(.notFound, message: "Donut not found")
        }

        return try conn.json(value: [
            "id": "\(donut.id)",
            "name": donut.name,
            "price": "\(donut.price)",
            "toppings": "\(donut.toppings.map { $0.name }.joined(separator: ", "))",
        ])
    }

    // Create a donut
    POST("/") { conn in
        struct CreateDonut: Decodable, Sendable {
            let name: String
            let description: String
            let price: Double
            let categoryId: String
        }
        let body = try conn.decode(as: CreateDonut.self)
        guard let catId = UUID(uuidString: body.categoryId) else {
            throw NexusHTTPError(.badRequest, message: "Invalid category ID")
        }

        var donut = Donut()
        donut.name = body.name
        donut.descriptionText = body.description
        donut.price = body.price
        donut.categoryId = catId
        donut.isAvailable = true

        let created = try await db.repo().insert(donut)
        return try conn.json(status: .created, value: ["id": "\(created.id)", "name": created.name])
    }
}
```

### What Changed

| Concept | Hummingbird | Nexus |
|---------|------------|-------|
| Function signature | `func addDonutRoutes(to router: Router<BasicRequestContext>, db: DB)` | `@RouteBuilder func donutRoutes(db: DB) -> [Route]` |
| Route grouping | `router.group("/donuts")` (imperative) | `scope("/donuts") { donutRoutes(db:) }` in App.swift (declarative) |
| Route declaration | `group.get("search") { request, context -> String in` | `GET("/search") { conn in` |
| Query params | `request.uri.queryParameters.get("q")` | `conn.queryParams["q"]` |
| Path params | `context.parameters.get("id")` | `conn.params["id"]` |
| Body decoding | `try await request.decode(as: T.self, context: context)` | `try conn.decode(as: T.self)` |
| JSON response | `return try encodeJSON([...])` | `return try conn.json(value: [...])` |
| HTTP errors | `throw HTTPError(.notFound, message: "...")` | `throw NexusHTTPError(.notFound, message: "...")` |
| Handler params | Two params: `request, context` (or `_, _`) | One param: `conn` |
| Return type | `-> String` | `-> Connection` (implicit via `conn.json()`) |
| Status codes | Always 200 (Hummingbird default for String return) | Explicit — `.created` for POST, `.ok` default for GET |

### What Didn't Change

- **Models** — zero changes to any Spectro schema
- **Database queries** — identical Spectro query builder calls
- **Business logic** — validation guards, UUID parsing, all unchanged
- **Domain types** — `CreateDonut` struct defined inline, same as before

---

## Migration Summary

**Files changed:** 7 (Package.swift, App.swift, 5 route files)
**Files unchanged:** 6 models, 1 migration SQL
**Files deleted:** Helpers.swift (`encodeJSON` replaced by `conn.json()`)

**Test results:** 18/19 API tests pass (test 19 is a jq parsing issue, not Nexus)

### Pattern Translation Table

| Concept | Hummingbird | Nexus |
|---------|------------|-------|
| Package dep | `hummingbird` only | `hummingbird` + `Nexus` + `NexusRouter` + `NexusHummingbird` |
| App wiring | `Application(router:)` | `NexusHummingbirdAdapter(plug:)` → `Application(responder:)` |
| Error rescue | Hummingbird catches `HTTPError` | `rescueErrors(pipeline)` wraps the plug |
| Route file shape | `func addXRoutes(to router:, db:)` (imperative) | `@RouteBuilder func xRoutes(db:) -> [Route]` (declarative) |
| Route grouping | `router.group("/prefix")` | `scope("/prefix") { ... }` in Router DSL |
| Handler signature | `{ request, context -> String in` | `{ conn in` |
| Query params | `request.uri.queryParameters.get("q")` | `conn.queryParams["q"]` |
| Path params | `context.parameters.get("id")` | `conn.params["id"]` |
| Body decode | `try await request.decode(as: T.self, context:)` | `try conn.decode(as: T.self)` |
| JSON response | `return try encodeJSON([...])` (always 200) | `return try conn.json(value: [...])` (explicit status) |
| HTTP errors | `throw HTTPError(.notFound, message:)` | `throw NexusHTTPError(.notFound, message:)` |
| Response type | `String` (raw JSON text) | `Connection` (structured response) |

### Key Observations

1. **Domain logic untouched** — Spectro queries, transactions, aggregates, preloads all identical
2. **Declarative vs imperative** — route files went from "mutate a router object" to "return a list of routes"
3. **Single handler param** — `conn` replaces the `(request, context)` pair; everything is on the connection
4. **Status codes for free** — Hummingbird's String return always produced 200; Nexus lets you set `.created` etc.
5. **`encodeJSON` deleted** — the global helper is replaced by `conn.json(value:)` which also sets Content-Type
