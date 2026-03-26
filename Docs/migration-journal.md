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

---

## Sprint Progress Log

A record of Nexus from scaffold to production-capable framework in one session.

### Sprint 0 — Scaffold
Repository foundation: `Connection`, `Plug` typealias, `RequestBody`/`ResponseBody` enums, `pipe`/`pipeline` composition, CI workflow.

### Sprint 1 — Router DSL
Result-builder router: `Route`, `PathPattern`, `RouteBuilder`, `GET`/`POST`/`PUT`/`DELETE`/`PATCH` helpers, first-match dispatch, 404/405, parameterized paths via `:id` segments.

### Sprint 2 — Hummingbird Adapter + Route Composition
`NexusHummingbirdAdapter` (HTTPResponder), buffered request bodies, `scope()` with prefix grouping, `scope(_:through:)` per-scope middleware, `Router.callAsFunction`, typed `conn.params`, percent-decoding, `HEAD`/`OPTIONS` helpers, auto-HEAD-to-GET fallback.

### Sprint 3 — Lifecycle Hooks + ConfigurablePlug (ADR-006)
`beforeSend` LIFO callbacks on Connection, `registerBeforeSend`/`runBeforeSend`, adapter integration. `ConfigurablePlug` protocol with `Options`/`init(options:)`/`call(_:)` and `asPlug()` bridge.

### Sprint 4 — Convenience Layer
`conn.queryParams`, `conn.decode(as:)` (JSON → Decodable), `conn.json(status:value:)` (Encodable → JSON response with Content-Type). `NexusHTTPError` + `rescueErrors(_:)` (throw-to-halt bridge). DonutShop ported and running — 18/19 API tests passing.

### Sprint 5 — JSONValue, Plug Library, Forward, Wildcards
`conn.jsonBody()` → `JSONValue` with typed accessors for dynamic JSON access. `requestLogger()`, `requestId()`, `corsPlug()` — first shipped plugs. `forward(_:to:)` sub-router delegation. `*`/`*rest` wildcard catch-all in PathPattern.

### Sprint 6 — Developer Ergonomics
`NexusTest` target with `TestConnection.build()`. Connection convenience helpers: `putRespHeader`, `deleteRespHeader`, `getReqHeader`, `putRespContentType`, `putStatus` (non-halting), `host`/`scheme` accessors. `ANY()` catch-all method route. `basicAuth()` plug with `WWW-Authenticate` challenge. `sslRedirect()` plug for HTTPS enforcement.

### Test Growth

| Sprint | Tests | Suites |
|--------|-------|--------|
| 0-1 | 43 | 5 |
| 2 | 86 | 10 |
| 3 | 102 | 12 |
| 4 | 129 | 17 |
| 5 | 162 | 23 |
| 6 | 180 | 27 |

### Nexus vs Elixir Plug Coverage (after Sprint 6)

| Area | Coverage |
|------|----------|
| Conn fields/functions | ~80% (missing: cookies, remote_ip, private, merged params) |
| Router features | ~95% (missing: match-any-method as standalone) |
| Built-in plugs | ~50% (have: Logger, RequestId, CORS, BasicAuth, SSL. Missing: Parsers, Static, Session, CSRF) |
| Test helpers | Started (NexusTest target) |
| Crypto | 0% (no signing/encryption — needed for sessions) |

### What's Next

**Sprint 7 (Tier 2):** Cookies, URL-encoded body parsing, `conn.remote_ip`, chunked responses, `send_file`
**Sprint 8 (Tier 3):** `Plug.Crypto` (CryptoKit), `Plug.Session`, CSRF protection, multipart parsing, static file serving
